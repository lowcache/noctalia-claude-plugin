-- Spec — drives orb.luau through its real surface: the captured c3.pulse watch
-- callback (__watch["c3.pulse"], the bar-pulse mirror) and the global onFrameTick
-- (the host frame clock). Concatenated AFTER orb.luau, so onFrameTick, __watch, and
-- the recorded __tree are in scope. find()/near()/between() come from the orb prelude.
-- The orb is a magnifying state glyph ("bat signal"): size and opacity breathe via
--   x = 0.5 - 0.5*cos(2π·phase/period)   (0 at phase 0, 1 at half period)
--   opacity = omin + (omax-omin)*x       size = GLYPH_MIN + (GLYPH_MAX-GLYPH_MIN)*x
-- With GLYPH_MIN=70, GLYPH_MAX=75. onFrameTick takes dt in MILLISECONDS (phase += dt/1000).

-- Load asked the host for frame ticks and rendered a calm idle orb at phase 0
-- (raised cosine is 0 there → opacity at idle's omin = 0.45, size at GLYPH_MIN).
expect("load → requests frame ticks", __tick, true)
expect("load → renders a column root", __tree.type, "column")
local glyph, label = find(__tree, "glyph"), find(__tree, "label")
expect("idle icon is the robot", glyph.props.name, "robot")
expect("idle icon is the green accent", glyph.props.color, "secondary")
near("idle opens at omin opacity", glyph.props.opacity, 0.45)
near("idle opens at min magnification", glyph.props.size, 70)
contains("idle label says idle", label.props.text, "idle")

-- A session needs attention → red icon, alarm glyph, urgent burn line.
__watch["c3.pulse"]({ state = "needs_attention", count = 1, model = "opus-4-8", tin = 1000, tout = 200 })
glyph, label = find(__tree, "glyph"), find(__tree, "label")
expect("needs-you icon rings the bell", glyph.props.name, "bell-ringing")
expect("needs-you icon turns red", glyph.props.color, "error")
near("state change renders at phase 0 → omin", glyph.props.opacity, 0.55)
contains("single-session label names the state", label.props.text, "needs you")
contains("single-session label shows the burn", label.props.text, "1.0k/200")

-- The breath: half a period in, the icon peaks (max size + omax); a full period resets.
onFrameTick(2250) -- dt is ms; needs_attention period 4.5s → half = 2250ms → cos(π) → x=1
near("half-breath peaks at omax opacity", find(__tree, "glyph").props.opacity, 1.00)
near("half-breath peaks at max magnification", find(__tree, "glyph").props.size, 75)
onFrameTick(2250) -- another 2250ms → full 4.5s period → wraps to phase 0 → x=0
near("full breath returns to omin", find(__tree, "glyph").props.opacity, 0.55)
near("full breath returns to min size", find(__tree, "glyph").props.size, 70)

-- Across the whole breath, opacity and size stay within their bounds.
for _ = 1, 40 do
  onFrameTick(37) -- ms
  local g = find(__tree, "glyph")
  between("opacity stays within bounds", g.props.opacity, 0.55, 1.00)
  between("size stays within magnification bounds", g.props.size, 70, 75)
end

-- Several sessions → the icon carries the most-urgent state; the label counts them.
__watch["c3.pulse"]({ state = "tool_start", count = 3 })
glyph, label = find(__tree, "glyph"), find(__tree, "label")
expect("multi-session icon reflects the rollup state", glyph.props.name, "tool")
expect("tool state uses the green accent", glyph.props.color, "secondary")
contains("multi-session label counts sessions", label.props.text, "3 sessions")

-- A malformed snapshot is ignored (state holds; no crash).
__watch["c3.pulse"]("garbage")
expect("non-table snapshot is ignored", find(__tree, "glyph").props.name, "tool")

-- An empty/partial snapshot defaults cleanly to idle rather than erroring.
__watch["c3.pulse"]({})
glyph, label = find(__tree, "glyph"), find(__tree, "label")
expect("empty snapshot falls back to idle icon", glyph.props.name, "robot")
expect("empty snapshot falls back to idle accent", glyph.props.color, "secondary")
expect("zero-session idle label has no burn", label.props.text, "idle")

-- A bad frame delta can't corrupt the phase accumulator (treated as 0).
onFrameTick("not a number")
between("bad dt leaves opacity valid", find(__tree, "glyph").props.opacity, 0.45, 0.80)

done()
