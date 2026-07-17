-- Spec — drives pulse.luau through its public surface: the global onIpc (hook
-- reflex, per-session, with the CSV payload) and the POLLED quick-ask path
-- (noctalia.state.set("claude.state", …) picked up by a update() tick, the way a
-- real bar sees it — bars don't fire state.watch). Concatenated AFTER pulse.luau, so
-- onIpc, update, and the recorded __tt/__glyph are in scope. opus token figures are
-- the tether-cross-checked totals (in 45129, cc 202412 → 247541 displayed).

-- Load ran render() with no sessions → clean idle.
expect("load → idle tooltip", __tt, "Claude: idle")
expect("load → robot glyph", __glyph, "robot")
expect("load → idle uses secondary accent at peak", __color, "#EAFF00")

-- One session, full telemetry → single-session burn tooltip + bell.
onIpc("turn_end", "opus-4-8,45129,112432,202412,4589306,alpha")
expect("1 session → burn tooltip", __tt,
  "Claude: done — ready for you\nopus-4-8 · 247.5k in / 112.4k out · 4.6M cached")
expect("1 session → bell glyph", __glyph, "bell")
expect("turn_end uses primary accent", __color, "#B4FF00")

-- Same session updates in place (same sid) → still one session, new numbers.
onIpc("tool_start", "opus-4-8,50000,120000,200000,5000000,alpha")
expect("same sid updates in place", __tt,
  "Claude: running a tool\nopus-4-8 · 250.0k in / 120.0k out · 5.0M cached")
expect("same sid → tool glyph", __glyph, "tool")
expect("tool uses secondary accent", __color, "#EAFF00")

-- A second session appears → aggregate view; glyph = most urgent (tool > thinking).
onIpc("turn_start", "haiku-4-5,1200,340,0,0,beta")
expect("2 sessions → tool glyph (priority)", __glyph, "tool")
expect("2 sessions → aggregate tooltip", __tt,
  "Claude — 2 sessions\n" ..
  "beta · thinking · haiku-4-5 1.2k/340\n" ..
  "alpha · tool · opus-4-8 250.0k/120.0k\n" ..
  "Σ 251.2k in / 120.3k out")

-- Urgency wins: beta needs you → bell-ringing regardless of recency/order.
onIpc("needs_attention", "haiku-4-5,1200,340,0,0,beta")
expect("needs_attention → bell-ringing glyph", __glyph, "bell-ringing")
expect("needs_attention uses error accent", __color, "#FF4D1F")
contains("needs_attention tooltip lists beta", __tt, "beta · needs you · haiku-4-5 1.2k/340")

-- Quick-ask (claude.state path) joins as an ephemeral, telemetry-less session.
-- Driven the real way: set the state, then a timer tick polls it (a bar never gets
-- a watch callback — this is the regression guard for that bug).
noctalia.state.set("claude.state", "turn_start"); update()
contains("ask adds a session", __tt, "Claude — 3 sessions")
contains("ask shown without burn", __tt, "ask · thinking")
expect("ask doesn't lower urgency", __glyph, "bell-ringing")

-- Ask completes → dropped (answer goes out via notify), back to two sessions.
noctalia.state.set("claude.state", "turn_end"); update()
contains("ask removed → 2 sessions", __tt, "Claude — 2 sessions")
absent("ask gone from tooltip", __tt, "ask ·")

-- SessionEnd retires a session.
onIpc("session_end", "opus-4-8,0,0,0,0,alpha")
expect("session_end → 1 session, beta single view", __tt,
  "Claude needs you\nhaiku-4-5 · 1.2k in / 340 out")
expect("session_end keeps beta urgency", __glyph, "bell-ringing")

-- Last session ends → clean idle again.
onIpc("session_end", "haiku-4-5,0,0,0,0,beta")
expect("all ended → idle tooltip", __tt, "Claude: idle")
expect("all ended → robot glyph", __glyph, "robot")
expect("all ended → secondary accent", __color, "#EAFF00")

-- A session with no real telemetry yet (SessionStart before first turn) shows
-- just its state, no "? 0/0" noise.
onIpc("idle", "?,0,0,0,0,gamma")
expect("zero-telemetry session → clean state", __tt, "Claude: idle")

-- Retire gamma to exercise the manual/CLI "default" slot in isolation.
onIpc("session_end", "?,0,0,0,0,gamma")

-- A payload-less event (manual `noctalia msg … :pulse all <event>` poke) lands in the
-- single "default" slot and is shown, so the orb can be driven from the CLI.
onIpc("needs_attention", "")
expect("payload-less poke shows in the default slot", __glyph, "bell-ringing")
expect("default slot has no burn", __tt, "Claude needs you")
onIpc("tool_start", "")
expect("default slot updates in place", __glyph, "tool")

-- It must never become sticky: any resting state (idle/turn_end/error) retires it,
-- so a manual test can't leave a phantom session lingering until a reload.
onIpc("idle", "")
expect("resting idle retires the default slot", __glyph, "robot")
expect("default cleared → idle tooltip", __tt, "Claude: idle")
onIpc("needs_attention", "")
onIpc("turn_end", "")
expect("resting turn_end also retires default", __tt, "Claude: idle")
onIpc("needs_attention", "")
onIpc("error", "")
expect("resting error also retires default", __glyph, "robot")

-- A real (payload-bearing) session is unaffected by the manual-rest rule: idle/turn_end
-- keep it; only session_end retires it.
onIpc("idle", "opus-4-8,10,20,0,0,delta")
expect("real session idle is kept (not retired)", __tt, "Claude: idle\nopus-4-8 · 10 in / 20 out")
onIpc("session_end", "opus-4-8,0,0,0,0,delta")
expect("real session retires only on session_end", __glyph, "robot")

-- The breath: state changes render at peak brightness (asserted above as the full
-- accent hex); timer ticks advance the phase and dim the glyph without touching
-- the glyph or tooltip (those are event-driven).
local tt_before, glyph_before = __tt, __glyph
for _ = 1, 33 do update() end -- ~2 s into the 8 s idle cycle
expect("breath dims off-peak", __color ~= "#EAFF00", true)
contains("breath color stays a 6-digit hex", __color, "#")
expect("timer tick leaves glyph alone", __glyph, glyph_before)
expect("timer tick leaves tooltip alone", __tt, tt_before)

done()
