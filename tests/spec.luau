-- Spec — drives pulse.luau through its public surface: the global onIpc (hook
-- reflex, per-session, with the CSV payload) and the captured cc.state callback
-- (__watch_cb, the quick-ask path). Concatenated AFTER pulse.luau, so onIpc,
-- __watch_cb, and the recorded __tt/__glyph are in scope. opus token figures are
-- the tether-cross-checked totals (in 45129, cc 202412 → 247541 displayed).

-- Load ran render() with no sessions → clean idle.
expect("load → idle tooltip", __tt, "Claude: idle")
expect("load → robot glyph", __glyph, "robot")
expect("load → idle uses green secondary", __color, "secondary")

-- One session, full telemetry → single-session burn tooltip + bell.
onIpc("turn_end", "opus-4-8,45129,112432,202412,4589306,alpha")
expect("1 session → burn tooltip", __tt,
  "Claude: done — ready for you\nopus-4-8 · 247.5k in / 112.4k out · 4.6M cached")
expect("1 session → bell glyph", __glyph, "bell")
expect("turn_end uses orange primary", __color, "primary")

-- Same session updates in place (same sid) → still one session, new numbers.
onIpc("tool_start", "opus-4-8,50000,120000,200000,5000000,alpha")
expect("same sid updates in place", __tt,
  "Claude: running a tool\nopus-4-8 · 250.0k in / 120.0k out · 5.0M cached")
expect("same sid → tool glyph", __glyph, "tool")
expect("tool uses green secondary", __color, "secondary")

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
expect("needs_attention stays red", __color, "error")
contains("needs_attention tooltip lists beta", __tt, "beta · needs you · haiku-4-5 1.2k/340")

-- Quick-ask (cc.state path) joins as an ephemeral, telemetry-less session.
__watch_cb("turn_start")
contains("ask adds a session", __tt, "Claude — 3 sessions")
contains("ask shown without burn", __tt, "ask · thinking")
expect("ask doesn't lower urgency", __glyph, "bell-ringing")

-- Ask completes → dropped (answer goes out via notify), back to two sessions.
__watch_cb("turn_end")
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
expect("all ended → green secondary", __color, "secondary")

-- A session with no real telemetry yet (SessionStart before first turn) shows
-- just its state, no "? 0/0" noise.
onIpc("idle", "?,0,0,0,0,gamma")
expect("zero-telemetry session → clean state", __tt, "Claude: idle")

done()
