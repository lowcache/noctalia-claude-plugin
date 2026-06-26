-- The attention pulse (bar widget) — a glanceable live readout of Claude's state.
-- Two feeds converge on apply():
--   • cc.luau writes "cc.state" (the launcher/ask path) → watched here.
--   • Claude Code hooks fire the plugin-dispatch IPC → onIpc here (the reflex):
--       noctalia msg plugin lowcache/claude:pulse all <event>
--     (verified against noctalia 5.0.0 source; see hooks/settings.snippet.json.)
--
-- Bar widgets do DISCRETE state (glyph/color/tooltip), not per-frame animation.
-- The bar API is the `barWidget.*` table (NOT `widget`). Glyph names are Tabler
-- icon names; an unknown name renders the skull fallback.
-- [CEILING]: smooth breathing + softness halo (the "wow") needs the desktop
-- "presence orb" variant — a [[desktop_widget]] with setNeedsFrameTick/onFrameTick.
-- This bar dot is v1; the orb is v1.1. Upgrade = add an orb entry, same state map.

local VISUAL = {
  idle            = { glyph = "robot",          color = "on_surface_variant", tip = "Claude: idle" },
  turn_start      = { glyph = "brain",          color = "primary",  tip = "Claude: thinking" },
  text            = { glyph = "message-dots",   color = "primary",  tip = "Claude: responding" },
  tool_start      = { glyph = "tool",           color = "tertiary", tip = "Claude: running a tool" },
  needs_attention = { glyph = "bell-ringing",   color = "error",    tip = "Claude needs you" },
  turn_end        = { glyph = "bell",           color = "primary",  tip = "Claude: done — ready for you" },
  error           = { glyph = "alert-triangle", color = "error",    tip = "Claude: error" },
}

-- Token-burn telemetry (hook reflex path only). hooks/pulse.py sends a space-free
-- CSV payload "model,in,out,cacheCreate,cacheRead,session" alongside the event.
-- We retain the last telemetry so high-frequency events that arrive without a
-- fresh parse still render the current burn; `idle` (only fired at SessionStart)
-- clears it so a new session never shows the previous session's numbers — the bar
-- widget is a persistent subprocess that outlives any single Claude session.
local last_tel = nil

local function split(s, sep)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
  return out
end

local function kfmt(s)
  local n = tonumber(s) or 0
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1000 then return string.format("%.1fk", n / 1000) end
  return tostring(math.floor(n))
end

-- tel = "model,in,out,cacheCreate,cacheRead,session". "in" (fresh prompt tokens)
-- is tiny next to cache reads, so reporting it alone understates the burn. Show
-- full-rate input (fresh + cache-create) vs output, and cached reads separately
-- (cheap, repeated context) so the figure reflects what the turn actually cost.
local function compose(tip, tel)
  if not tel or tel == "" then return tip end
  local f = split(tel, ",")
  local model = (f[1] and f[1] ~= "") and f[1] or "?"
  local tin = (tonumber(f[2]) or 0) + (tonumber(f[4]) or 0)
  local cached = tonumber(f[5]) or 0
  local line = string.format("%s · %s in / %s out", model, kfmt(tin), kfmt(f[3]))
  if cached > 0 then line = line .. " · " .. kfmt(cached) .. " cached" end
  return tip .. "\n" .. line
end

local function apply(s, tel)
  local v = VISUAL[s] or VISUAL.idle
  if s == "idle" then last_tel = nil end
  if tel ~= nil and tel ~= "" then last_tel = tel end
  barWidget.setGlyph(v.glyph)
  barWidget.setGlyphColor(v.color)
  barWidget.setTooltip(compose(v.tip, last_tel))
end

-- launcher/ask path: cc.luau publishes the normalized event name here (no payload).
noctalia.state.watch("cc.state", function(s)
  if type(s) == "string" then apply(s) end
end)

-- hook reflex path. The dispatcher calls onIpc(event, payload); payload is the
-- telemetry CSV (or absent for events with nothing to report yet).
function onIpc(event, payload)
  if type(event) == "string" then apply(event, payload) end
end

apply("idle")
