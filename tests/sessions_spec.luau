-- Spec for sessions.luau — the actionable per-session panel.
-- Drives the real panel through the real claude.pulse shape published by
-- pulse-svc, then fires the captured button closures to assert the exact IPC the
-- retire control emits. Concatenated AFTER sessions_prelude + sessions.luau.

-- 1. Empty state
__state["claude.pulse"] = { state = "idle", count = 0, sessions = {} }
onOpen(nil)
expect("panel arms second ticks", __ticks, true)
contains("empty state names zero sessions", text_of(__tree), "0 sessions")
contains("empty state explains how to start one", text_of(__tree), "No live Claude sessions")
expect("no retire buttons with no sessions", #collect(__tree, "button"), 0)

-- 2. Two live sessions, most-recent first (the order pulse-svc publishes)
__state["claude.pulse"] = {
  state = "needs_attention", count = 2,
  sessions = {
    { sid = "sess-beta",  state = "needs_attention", model = "sonnet", tin = 400,  tout = 120, cr = 900 },
    { sid = "sess-alpha", state = "tool_start",      model = "opus",   tin = 2000, tout = 340, cr = 5000 },
  },
}
update()
local body = text_of(__tree)
contains("header counts both sessions", body, "2 sessions")
contains("first session id shown", body, "sess-beta")
contains("second session id shown", body, "sess-alpha")
contains("state word is localized, not raw", body, "needs you")
contains("tool state word localized", body, "tool")
contains("model and burn shown", body, "opus 2.0k/340")
contains("cache reads shown", body, "5.0k cached")
contains("sigma total across sessions", body, "2.4k in / 460 out")
expect("one retire button per session", #collect(__tree, "button"), 2)
expect("retire button is tinted, not left at the background color",
  collect(__tree, "button")[1].props.variant, "secondary")

-- 3. The retire control emits the documented protocol, nothing new
local buttons = collect(__tree, "button")
buttons[1].props.onClick()
expect("one command dispatched", #__async, 1)
expect(
  "retire is a session-tagged session_end, not a new verb",
  __async[1],
  "noctalia msg plugin 'lowcache/claude-companion:pulse-svc' all session_end ',,,,,sess-beta'"
)
buttons[2].props.onClick()
expect("second retire targets the other session", __async[2],
  "noctalia msg plugin 'lowcache/claude-companion:pulse-svc' all session_end ',,,,,sess-alpha'")

-- 4. Render guard: an unchanged snapshot must not re-render (it would reset scroll)
local before = __renders
update()
expect("no re-render when the rollup is unchanged", __renders, before)
__state["claude.pulse"].sessions[1].tout = 999
update()
expect("re-renders when telemetry changes", __renders, before + 1)

-- 5. A session id that could reach the shell is refused, not quoted
__state["claude.pulse"] = {
  state = "idle", count = 1,
  sessions = { { sid = "evil'; rm -rf ~ #", state = "idle", model = "?", tin = 0, tout = 0, cr = 0 } },
}
update()
expect("hostile session id gets no retire control", #collect(__tree, "button"), 0)
local n_async = #__async
update()
expect("and dispatches nothing", #__async, n_async)

-- 6. A session with no telemetry yet still lists, and stays retirable
__state["claude.pulse"] = {
  state = "idle", count = 1,
  sessions = { { sid = "fresh", state = "idle", model = "?", tin = 0, tout = 0, cr = 0 } },
}
update()
body = text_of(__tree)
contains("single session header is singular, not \"1 sessions\"", body, "1 session")
absent("singular header does not say \"1 sessions\"", body, "1 sessions")
contains("zero-burn session still listed", body, "fresh")
absent("no burn figures for a zero-burn session", body, "0/0")
expect("zero-burn session is retirable", #collect(__tree, "button"), 1)
collect(__tree, "button")[1].props.onClick()
expect("retires the fresh session", __async[#__async],
  "noctalia msg plugin 'lowcache/claude-companion:pulse-svc' all session_end ',,,,,fresh'")

-- 7. The ephemeral quick-ask pseudo-session is retirable like any other
__state["claude.pulse"] = {
  state = "text", count = 1,
  sessions = { { sid = "ask", state = "text", model = "?", tin = 0, tout = 0, cr = 0 } },
}
update()
contains("quick-ask session listed", text_of(__tree), "ask")
expect("quick-ask session is retirable", #collect(__tree, "button"), 1)

done()
