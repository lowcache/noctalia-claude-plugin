-- Spec — drives pulse.luau through its public surface (the global onIpc + the
-- barWidget stub). Concatenated AFTER pulse.luau, so onIpc and the recorded
-- __tt/__glyph are in scope. Token figures below are the tether-cross-checked
-- totals from a real opus-4-8 transcript (in 45129, out 112432, cc 202412,
-- cr 4589306) → displayed input = 45129 + 202412 = 247541.

-- Loading pulse.luau already ran apply("idle").
expect("load → idle tooltip", __tt, "Claude: idle")
expect("load → robot glyph", __glyph, "robot")

-- Full telemetry payload: input = fresh + cache-create; cache reads shown apart.
onIpc("turn_end", "opus-4-8,45129,112432,202412,4589306,verify")
expect("turn_end → burn tooltip", __tt,
  "Claude: done — ready for you\nopus-4-8 · 247.5k in / 112.4k out · 4.6M cached")
expect("turn_end → bell glyph", __glyph, "bell")

-- Payload-less event retains the last telemetry (high-frequency reflex events).
onIpc("tool_start")
expect("tool_start → retains burn", __tt,
  "Claude: running a tool\nopus-4-8 · 247.5k in / 112.4k out · 4.6M cached")

-- Small counts, no cache reads → the "cached" segment is omitted, plain ints.
onIpc("turn_start", "haiku-4-5,1200,340,0,0,abc")
expect("turn_start → no-cache format", __tt, "Claude: thinking\nhaiku-4-5 · 1.2k in / 340 out")

-- idle must clear telemetry: the bar widget outlives a session, so a NEW
-- session's idle must never show the previous session's burn.
onIpc("idle")
expect("idle → clears burn", __tt, "Claude: idle")

-- Empty-string payload is treated as absent (no trailing burn line).
onIpc("error", "")
expect("error → empty payload", __tt, "Claude: error")

-- Unknown state falls back to idle visuals.
onIpc("bogus")
expect("unknown state → idle fallback glyph", __glyph, "robot")

done()
