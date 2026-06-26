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
  turn_end        = { glyph = "circle-check",   color = "primary",  tip = "Claude: done" },
  error           = { glyph = "alert-triangle", color = "error",    tip = "Claude: error" },
}

local function apply(s)
  local v = VISUAL[s] or VISUAL.idle
  barWidget.setGlyph(v.glyph)
  barWidget.setGlyphColor(v.color)
  barWidget.setTooltip(v.tip)
end

-- launcher/ask path: cc.luau publishes the normalized event name here.
noctalia.state.watch("cc.state", function(s)
  if type(s) == "string" then apply(s) end
end)

-- hook reflex path. The dispatcher calls onIpc(event, payload) with two string
-- args; payload is unused for now (reserved for e.g. model/cost context later).
function onIpc(event, _payload)
  if type(event) == "string" then apply(event) end
end

apply("idle")
