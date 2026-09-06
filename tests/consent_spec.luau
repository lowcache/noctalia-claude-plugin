-- Behaviour spec for consent.luau. Concatenated AFTER the entry, so onOpen/onClose/
-- update and the rendered tree are all in scope.
--
-- The property that matters is not "does it render" but "does every outstanding
-- request eventually get a surface, and does a dismissed one release the tool call".
-- Claude batches tool calls, so more than one prompt at a time is the normal case.

local BASE = { tool = "Bash", key = "Bash:npm test", command = "npm test",
               description = "Run the test suite", cwd = "/home/u/proj",
               session = "abcd1234", path = "" }

local function req(over)
  local r = {}
  for k, v in pairs(BASE) do r[k] = v end
  for k, v in pairs(over or {}) do r[k] = v end
  return r
end

local function reset()
  __files = {}
  __cmds = {}
  __state = {}
  __tree = nil
  __renders = 0
end

-- ── empty state ──────────────────────────────────────────────────────────────
reset()
onOpen(nil)
expect("panel arms second ticks", __ticks, true)
contains("empty state when nothing is pending", __rendered(), "Nothing is waiting on you")
expect("empty state dispatches nothing", #__cmds, 0)

-- ── a single pending request ─────────────────────────────────────────────────
reset()
__put("A", req())
__queue("A")
onOpen("A")
contains("names the tool", __rendered(), "Claude wants to run Bash")
contains("shows the command", __rendered(), "npm test")
contains("shows the description", __rendered(), "Run the test suite")
contains("shows the cwd", __rendered(), "/home/u/proj")
contains("says what happens if ignored", __rendered(), "asks in the terminal")
expect("three answers offered", #__buttons(), 3)

-- ── the three verdicts ───────────────────────────────────────────────────────
reset(); __put("A", req()); __queue("A"); onOpen("A")
expect("allow once clicked", __click("Allow once"), true)
contains("dispatches an allow reply", __cmds[1], "reply 'A' allow")

reset(); __put("A", req()); __queue("A"); onOpen("A")
__click("Always allow")
contains("always is its own verb, resolved hook-side", __cmds[1], "reply 'A' always")

reset(); __put("A", req()); __queue("A"); onOpen("A")
__click("Deny")
contains("dispatches a deny reply", __cmds[1], "reply 'A' deny")

-- The hook path carries $HOME and must expand, but a $HOME with a space must not
-- word-split -- so it is double-quoted, never bare.
contains("hook path is double-quoted", __cmds[1], '"$HOME/.local/share/noctalia')

-- ── ids are allowlisted, not quoted ──────────────────────────────────────────
reset()
__put("../../etc/passwd", req())
__queue("../../etc/passwd")
onOpen("../../etc/passwd")
contains("hostile id gets no surface", __rendered(), "Nothing is waiting on you")
expect("and dispatches nothing", #__cmds, 0)

-- ── concurrency: a batch of tool calls is a batch of prompts ─────────────────
-- Claude Code issues tool calls in parallel. Before the queue, the second request
-- overwrote the first in state, never re-entered onOpen on an already-open panel,
-- and stalled for its full 110s deadline with no surface ever shown.
reset()
__put("A", req({ command = "npm test" }))
__put("B", req({ command = "rm -rf build", key = "Bash:rm -rf build" }))
__queue("A", "B")
onOpen("A")
contains("first request shown", __rendered(), "npm test")
__click("Allow once")
__drop("A") -- the hook removes the request file once it has the reply
contains("answering the first advances to the second", __rendered(), "rm -rf build")
expect("panel did not close while one is still pending", __cmds_matching("panel-close"), 0)
__click("Deny")
__drop("B")
expect("both were answered", __cmds_matching("reply "), 2)
expect("panel closes once nothing is left", __cmds_matching("panel-close"), 1)

-- ── dismissal releases every prompt it was showing ───────────────────────────
-- Esc writes nothing on its own, so an un-dismissed request held the tool call for
-- the rest of its deadline. Closing the panel answers "not here" for all of them.
reset()
__put("A", req())
__put("B", req({ command = "ls" }))
__queue("A", "B")
onOpen("A")
onClose()
expect("both pending requests are dismissed", __cmds_matching(" dismiss"), 2)

-- Answering does not then dismiss what was answered.
reset(); __put("A", req()); __queue("A"); onOpen("A")
__click("Allow once")
__drop("A")
onClose()
expect("an answered request is not also dismissed", __cmds_matching(" dismiss"), 0)

-- ── the request going away under us ──────────────────────────────────────────
reset(); __put("A", req()); __queue("A"); onOpen("A")
__drop("A") -- hook hit its deadline and cleaned up
update()
contains("expired request drops to the empty state", __rendered(), "Nothing is waiting on you")

-- A quiet tick with nothing pending must not repaint: the panel is on second ticks.
local before = __renders
update()
expect("idle tick does not re-render", __renders, before)

done()
