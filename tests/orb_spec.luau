-- Spec — drives orb.luau through its real surface: the captured cc.pulse watch
-- callback (__watch["cc.pulse"], the bar-pulse mirror) and the global onFrameTick
-- (the host frame clock). Concatenated AFTER orb.luau, so onFrameTick, __watch, and
-- the recorded __tree/__tick are in scope. find()/near()/between() come from the orb
-- prelude. Opacity math: opacity = omin + (omax-omin) * (0.5 - 0.5*cos(2π·phase/period)).

-- Load asked the host for frame ticks and rendered a calm idle orb at phase 0
-- (raised cosine is 0 there → opacity sits at idle's omin = 0.42).
expect("load → requests frame ticks", __tick, true)
expect("load → renders a column root", __tree.type, "column")
local box, glyph, label = find(__tree, "box"), find(__tree, "glyph"), find(__tree, "label")
expect("idle disc is the green accent", box.props.backgroundColor, "secondary")
expect("disc is a circle (radius = D/2)", box.props.radius, 38)
expect("disc diameter", box.props.width, 76)
near("idle opens at omin opacity", box.props.opacity, 0.42)
expect("idle glyph is the robot", glyph.props.name, "robot")
expect("glyph uses the on-accent contrast token", glyph.props.color, "on_secondary")
contains("idle label says idle", label.props.text, "idle")

-- A session needs attention → red disc, alarm glyph, on_error contrast, burn line.
__watch["cc.pulse"]({ state = "needs_attention", count = 1, model = "opus-4-8", tin = 1000, tout = 200 })
box, glyph, label = find(__tree, "box"), find(__tree, "glyph"), find(__tree, "label")
expect("needs-you disc turns red", box.props.backgroundColor, "error")
expect("needs-you glyph rings the bell", glyph.props.name, "bell-ringing")
expect("needs-you glyph contrast", glyph.props.color, "on_error")
near("state change renders at current phase 0 → omin", box.props.opacity, 0.38)
contains("single-session label names the state", label.props.text, "needs you")
contains("single-session label shows the burn", label.props.text, "opus-4-8 1.0k/200")

-- The breath: half a period in, the disc peaks at omax; a full period returns to omin.
onFrameTick(0.425) -- needs_attention period 0.85 → half period → cos(π) → s=1
near("half-breath peaks at omax", find(__tree, "box").props.opacity, 1.00)
onFrameTick(0.425) -- full period → wraps to phase 0 → s=0
near("full breath returns to omin", find(__tree, "box").props.opacity, 0.38)

-- Opacity must never leave [omin, omax] no matter where in the breath we sample.
for _ = 1, 40 do
  onFrameTick(0.037)
  between("breath stays within bounds", find(__tree, "box").props.opacity, 0.38, 1.00)
end

-- Several sessions → the disc carries the most-urgent state; the label counts them.
__watch["cc.pulse"]({ state = "tool_start", count = 3 })
box, glyph, label = find(__tree, "box"), find(__tree, "glyph"), find(__tree, "label")
expect("multi-session disc reflects the rollup state", glyph.props.name, "tool")
expect("tool state uses the green accent", box.props.backgroundColor, "secondary")
contains("multi-session label counts sessions", label.props.text, "3 sessions")

-- A malformed snapshot is ignored (state holds; no crash).
__watch["cc.pulse"]("garbage")
expect("non-table snapshot is ignored", find(__tree, "glyph").props.name, "tool")

-- An empty/partial snapshot defaults cleanly to idle rather than erroring.
__watch["cc.pulse"]({})
box, glyph, label = find(__tree, "box"), find(__tree, "glyph"), find(__tree, "label")
expect("empty snapshot falls back to idle glyph", glyph.props.name, "robot")
expect("empty snapshot falls back to idle accent", box.props.backgroundColor, "secondary")
expect("zero-session idle label has no burn", label.props.text, "Claude: idle")

-- A bad frame delta can't corrupt the phase accumulator (treated as 0).
onFrameTick("not a number")
between("bad dt leaves opacity valid", find(__tree, "box").props.opacity, 0.42, 0.78)

done()
