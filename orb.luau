-- The presence orb (desktop widget) — the ambient "wow" half of the attention
-- pulse. Where the bar dot is a glanceable glyph, the orb is a softly *breathing*
-- disc on the desktop that radiates Claude's most-urgent state across every active
-- session: calm and slow at idle, quick and insistent when Claude needs you.
--
-- It is a pure VIEW. pulse.luau already rolls all sessions up for the bar dot and
-- now mirrors that rollup into noctalia.state ("cc.pulse"); the orb just subscribes
-- and animates. No hook, IPC, or session bookkeeping lives here — one source of
-- truth (the bar pulse), two surfaces (bar dot + desktop orb).
--
-- Unlike the bar dot's DISCRETE glyph/color, the orb does PER-FRAME motion:
-- desktopWidget.setNeedsFrameTick(true) asks the host for onFrameTick(dt) callbacks
-- (dt = seconds since last frame); a sine "breath" drives the disc opacity and a
-- subtle glyph scale. Breath speed/depth come from the state, so the motion itself
-- carries meaning. When nothing is animating differently we keep ticking a slow
-- idle breath — ambient presence is the whole point of the orb.
--
-- API surface (verified against noctalia 5.0.0):
--   desktopWidget.render(tree)            -- declarative ui.* tree
--   desktopWidget.setNeedsFrameTick(bool) -- opt into onFrameTick(dt)
--   ui.box{ width,height,radius,backgroundColor,opacity,shadow,align } + children
--   ui.glyph{ name,size,color }   ui.column/row   ui.label{ text,fontSize,color,... }
--   noctalia.state.watch(key, cb)
-- Colors are the global scheme accents (secondary/primary/error) — same map as the
-- bar dot — with the matching on_<accent> token for the glyph so it always reads on
-- top of the filled disc. See pulse.luau for the shared state→visual map.

-- Per-state look + motion. `color` is the disc accent (glyph uses on_<color>).
-- `period` = seconds per full breath; `omin`/`omax` = disc opacity bounds the breath
-- swings between. Faster + deeper = more urgent. `word` labels the state below.
local VISUAL = {
  idle            = { glyph = "robot",          color = "secondary", period = 5.0, omin = 0.42, omax = 0.78, word = "idle" },
  turn_start      = { glyph = "brain",          color = "primary",   period = 2.4, omin = 0.55, omax = 1.00, word = "thinking" },
  text            = { glyph = "message-dots",   color = "primary",   period = 1.9, omin = 0.60, omax = 1.00, word = "responding" },
  tool_start      = { glyph = "tool",           color = "secondary", period = 2.2, omin = 0.55, omax = 1.00, word = "running a tool" },
  needs_attention = { glyph = "bell-ringing",   color = "error",     period = 0.85, omin = 0.38, omax = 1.00, word = "needs you" },
  turn_end        = { glyph = "bell",           color = "primary",   period = 3.2, omin = 0.55, omax = 0.95, word = "done — ready for you" },
  error           = { glyph = "alert-triangle", color = "error",     period = 1.1, omin = 0.38, omax = 1.00, word = "error" },
}

-- on-accent contrast token for the glyph (all confirmed scheme colors).
local ON = { primary = "on_primary", secondary = "on_secondary", error = "on_error" }

local D = 76          -- orb diameter (logical px)
local GLYPH_BASE = 32 -- glyph size at mid-breath

-- Live status mirrored from the bar pulse. `count` 0 means no active sessions.
local cur = { state = "idle", count = 0, model = "?", tin = 0, tout = 0 }
local phase = 0.0     -- breath phase accumulator (seconds), wrapped per period

local function kfmt(n)
  n = tonumber(n) or 0
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1000 then return string.format("%.1fk", n / 1000) end
  return tostring(math.floor(n))
end

-- 0..1..0 over one period (raised cosine): 0 at phase 0, 1 at half period.
local function breath()
  local v = VISUAL[cur.state] or VISUAL.idle
  local s = 0.5 - 0.5 * math.cos((phase / v.period) * 2 * math.pi)
  return v, s
end

-- One status line under the orb: idle/working word, session count, or burn.
local function subtitle(v)
  if cur.count > 1 then
    return cur.count .. " sessions · " .. v.word
  end
  local line = "Claude: " .. v.word
  if cur.count == 1 and cur.model ~= "?" and (cur.tin + cur.tout) > 0 then
    line = line .. "  ·  " .. cur.model .. " " .. kfmt(cur.tin) .. "/" .. kfmt(cur.tout)
  end
  return line
end

local function render()
  local v, s = breath()
  local opacity = v.omin + (v.omax - v.omin) * s
  local glyphSize = GLYPH_BASE * (0.90 + 0.18 * s) -- subtle scale, in step with the breath

  desktopWidget.render(ui.column({ gap = 8, padding = 14, align = "center" }, {
    ui.box({
      width = D, height = D, radius = D / 2,   -- radius = D/2 → a circle
      backgroundColor = v.color, opacity = opacity,
      shadow = v.color,                          -- accent glow that breathes with the disc
      align = "center",
    }, {
      ui.glyph({ name = v.glyph, size = glyphSize, color = ON[v.color] or "on_surface" }),
    }),
    ui.label({
      text = subtitle(v), fontSize = 12, color = "on_surface_variant",
      maxWidth = 200, maxLines = 1, align = "center",
    }),
  }))
end

-- Per-frame breath. `dt` is seconds since the last frame; accumulate into `phase`
-- and wrap at the current state's period so the accumulator can't grow unbounded.
function onFrameTick(dt)
  local v = VISUAL[cur.state] or VISUAL.idle
  phase = (phase + (tonumber(dt) or 0)) % v.period
  render()
end

-- New status from the bar pulse. We don't reset `phase` on state change — the
-- breath glides into the new tempo instead of snapping, which reads calmer.
noctalia.state.watch("cc.pulse", function(snap)
  if type(snap) ~= "table" then return end
  cur.state = (type(snap.state) == "string" and VISUAL[snap.state]) and snap.state or "idle"
  cur.count = tonumber(snap.count) or 0
  cur.model = (type(snap.model) == "string" and snap.model ~= "") and snap.model or "?"
  cur.tin = tonumber(snap.tin) or 0
  cur.tout = tonumber(snap.tout) or 0
  render()
end)

-- Breathe from the first frame, even before any session reports in (idle presence).
desktopWidget.setNeedsFrameTick(true)
render()
