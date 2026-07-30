-- Spec — drives pulse.luau (the bar widget view) through its subscriber surface:
-- the captured claude.pulse watch callback (__watch["claude.pulse"]).
-- Concatenated AFTER pulse.luau, so __watch, update, onClick, and the recorded
-- __tt/__glyph/__color are in scope.
--
-- The bar is a PURE SUBSCRIBER of the rollup published by pulse-svc.luau.

-- 0. Regression & Architecture assertions
expect("regression: pulse.luau defines NO global onIpc", type(onIpc), "nil")
expect("regression: pulse.luau defines NO global sessions table", type(sessions), "nil")
expect("pulse.luau subscribes to claude.pulse watch", type(__watch["claude.pulse"]), "function")

-- 1. Load behavior (initial state with no published snapshot)
expect("load → idle tooltip", __tt, "Claude: idle")
expect("load → robot glyph", __glyph, "robot")
expect("load → idle uses secondary accent at peak", __color, "#EAFF00")

-- 2. Single-session snapshots across states (with & without burn line)
__watch["claude.pulse"]({
  state = "turn_end",
  count = 1,
  model = "opus-4-8",
  tin = 247541,
  tout = 112432,
  cr = 4589306,
})
expect("1 session → burn tooltip", __tt,
  "Claude: done — ready for you\nopus-4-8 · 247.5k in / 112.4k out · 4.6M cached")
expect("1 session → bell glyph", __glyph, "bell")
expect("turn_end uses primary accent", __color, "#B4FF00")

__watch["claude.pulse"]({
  state = "tool_start",
  count = 1,
  model = "opus-4-8",
  tin = 250000,
  tout = 120000,
  cr = 5000000,
})
expect("tool_start → tool glyph", __glyph, "tool")
expect("tool_start uses secondary accent", __color, "#EAFF00")
expect("tool_start tooltip", __tt,
  "Claude: running a tool\nopus-4-8 · 250.0k in / 120.0k out · 5.0M cached")

__watch["claude.pulse"]({
  state = "turn_start",
  count = 1,
  model = "opus-4-8",
  tin = 0,
  tout = 0,
  cr = 0,
})
expect("turn_start (no burn) → thinking glyph", __glyph, "brain")
expect("turn_start uses primary accent", __color, "#B4FF00")
expect("turn_start tooltip without burn line", __tt, "Claude: thinking")

__watch["claude.pulse"]({
  state = "needs_attention",
  count = 1,
  model = "haiku-4-5",
  tin = 1200,
  tout = 340,
  cr = 0,
})
expect("needs_attention → bell-ringing glyph", __glyph, "bell-ringing")
expect("needs_attention uses error accent", __color, "#FF4D1F")
expect("needs_attention tooltip with burn", __tt,
  "Claude needs you\nhaiku-4-5 · 1.2k in / 340 out")

__watch["claude.pulse"]({
  state = "error",
  count = 1,
  model = "opus-4-8",
  tin = 0,
  tout = 0,
  cr = 0,
})
expect("error → alert-triangle glyph", __glyph, "alert-triangle")
expect("error uses error accent", __color, "#FF4D1F")
expect("error tooltip", __tt, "Claude: error")

__watch["claude.pulse"]({
  state = "text",
  count = 1,
  model = "opus-4-8",
  tin = 100,
  tout = 50,
  cr = 0,
})
expect("text → message-dots glyph", __glyph, "message-dots")
expect("text uses primary accent", __color, "#B4FF00")
expect("text tooltip", __tt, "Claude: responding\nopus-4-8 · 100 in / 50 out")

__watch["claude.pulse"]({
  state = "idle",
  count = 1,
  model = "opus-4-8",
  tin = 10,
  tout = 20,
  cr = 0,
})
expect("idle with 1 session → robot glyph", __glyph, "robot")
expect("idle uses secondary accent", __color, "#EAFF00")
expect("idle tooltip with burn", __tt, "Claude: idle\nopus-4-8 · 10 in / 20 out")

-- 3. Multi-session tooltip formatting (divider lines & Sigma line)
__watch["claude.pulse"]({
  state = "tool_start",
  count = 2,
  model = "?",
  tin = 251200,
  tout = 120340,
  cr = 0,
  sessions = {
    { sid = "beta", state = "turn_start", model = "haiku-4-5", tin = 1200, tout = 340, cr = 0 },
    { sid = "alpha", state = "tool_start", model = "opus-4-8", tin = 250000, tout = 120000, cr = 0 },
  },
})
expect("2 sessions → tool glyph (rollup priority)", __glyph, "tool")
expect("2 sessions → aggregate tooltip with divider and Sigma", __tt,
  "Claude — 2 sessions\n" ..
  "beta · thinking · haiku-4-5 1.2k/340\n" ..
  "──────────────\n" ..
  "alpha · tool · opus-4-8 250.0k/120.0k\n" ..
  "──────────────\n" ..
  "Σ 251.2k in / 120.3k out")

-- Multi-session where one session is quick-ask (zero telemetry)
__watch["claude.pulse"]({
  state = "needs_attention",
  count = 2,
  model = "?",
  tin = 1200,
  tout = 340,
  cr = 0,
  sessions = {
    { sid = "beta", state = "needs_attention", model = "haiku-4-5", tin = 1200, tout = 340, cr = 0 },
    { sid = "ask", state = "turn_start", model = "?", tin = 0, tout = 0, cr = 0 },
  },
})
expect("2 sessions with ask → bell-ringing glyph", __glyph, "bell-ringing")
expect("2 sessions with ask → aggregate tooltip", __tt,
  "Claude — 2 sessions\n" ..
  "beta · needs you · haiku-4-5 1.2k/340\n" ..
  "──────────────\n" ..
  "ask · thinking\n" ..
  "──────────────\n" ..
  "Σ 1.2k in / 340 out")

-- Multi-session fallback when sessions[] array is empty (older publishers)
__watch["claude.pulse"]({
  state = "tool_start",
  count = 2,
  model = "?",
  tin = 250000,
  tout = 120000,
  cr = 0,
  sessions = {},
})
expect("2 sessions without sessions[] array → fallback Sigma tooltip", __tt,
  "Claude — 2 sessions\n" ..
  "──────────────\n" ..
  "Σ 250.0k in / 120.0k out")

-- Zero active sessions → clean idle
__watch["claude.pulse"]({
  state = "idle",
  count = 0,
  model = "?",
  tin = 0,
  tout = 0,
  cr = 0,
  sessions = {},
})
expect("0 sessions → clean idle tooltip", __tt, "Claude: idle")
expect("0 sessions → robot glyph", __glyph, "robot")
expect("0 sessions → secondary accent", __color, "#EAFF00")

-- 4. Malformed & empty snapshot resilience
__watch["claude.pulse"]("not a table")
expect("non-table snapshot is ignored", __glyph, "robot")

__watch["claude.pulse"]({})
expect("empty snapshot falls back to idle", __glyph, "robot")
expect("empty snapshot falls back to idle tooltip", __tt, "Claude: idle")
expect("empty snapshot falls back to secondary accent", __color, "#EAFF00")

-- 5. Click handler (panel open)
onClick()
expect("onClick invokes noctalia runAsync without error", __glyph, "robot")

-- 6. Breath timer (update advances phase without altering glyph/tooltip)
local tt_before, glyph_before = __tt, __glyph
for _ = 1, 33 do update() end -- ~2 s into the 8 s idle cycle
expect("breath dims off-peak", __color ~= "#EAFF00", true)
contains("breath color stays a 6-digit hex", __color, "#")
expect("timer tick leaves glyph alone", __glyph, glyph_before)
expect("timer tick leaves tooltip alone", __tt, tt_before)

-- 7. User settings (breath_speed, pulse_glow_floor)
local function phase_from_color(hex, period, gf)
  period = period or 8.0
  gf = gf or 0.45
  local g = tonumber(string.sub(hex, 4, 5), 16) / 255
  local s = (g - gf) / (1.0 - gf)
  local cos_val = 1.0 - 2.0 * s
  if cos_val > 1 then cos_val = 1 elseif cos_val < -1 then cos_val = -1 end
  return (period / (2 * math.pi)) * math.acos(cos_val)
end

__config.breath_speed = 2
for _ = 1, 128 do update() end -- cross PALETTE_EVERY (128 ticks) to invoke read_settings()
-- Snap breath to peak of idle (period 8.0)
__watch["claude.pulse"]({ state = "tool_start", count = 1 })
__watch["claude.pulse"]({ state = "idle", count = 1 })
for _ = 1, 17 do update() end -- advance ~2 s past peak where cosine slope is steepest
local p1 = phase_from_color(__color, 8.0, 0.45)
update()
local p2 = phase_from_color(__color, 8.0, 0.45)
local delta = math.abs(p2 - p1)
local ratio = delta / (60 / 1000)
near("breath_speed=2 advances phase ~2x per update tick", ratio, 2.0, 0.15)

__config.breath_speed = 1
__config.pulse_glow_floor = 0.7
for _ = 1, 128 do update() end -- cross PALETTE_EVERY to invoke read_settings()
-- Snap breath to peak of needs_attention (period 3.0 -> phase snaps to 1.5 s)
__watch["claude.pulse"]({ state = "idle", count = 1 })
__watch["claude.pulse"]({ state = "needs_attention", count = 1 })
-- Advance exactly 1.5 s (25 ticks at default breath_speed=1, 60ms/tick) -> phase reaches 3.0 (trough, s=0)
for _ = 1, 25 do update() end
local function level_from_color(hex)
  local r = tonumber(string.sub(hex, 2, 3), 16)
  local g = tonumber(string.sub(hex, 4, 5), 16)
  return math.max(r, g) / 255
end
near("pulse_glow_floor=0.7 at trough brightness level ~0.7", level_from_color(__color), 0.7, 0.02)
expect("trough brightness level is raised above default 0.45", level_from_color(__color) > 0.6, true)

done()
