-- Behaviour spec for ask.luau. Concatenated AFTER the entry.
--
-- One line of free-form user text reaches a shell command here, so the properties
-- worth pinning are that it is quoted rather than filtered, that Enter and the button
-- are the same path, and that a dispatch the host refused is never silent.

local function reset()
  __cmds = {}
  __errors = {}
  __run_ok = true
  __renders = 0
  onOpen(nil)
end

reset()
expect("opens with an empty field", __input().props.value, "")
expect("field takes focus so Enter works without a click", __input().props.focus, true)
contains("says where the answer arrives", tostring(__find(__tree, "label") and "ok"), "ok")

-- ── the two submit paths are one path ────────────────────────────────────────
reset()
__input().props.onSubmit("what is a monad")
expect("Enter dispatches once", __cmds_matching("all ask"), 1)
contains("question is written before the poke", __cmds[1], "/ask")
contains("and the poke targets the backend service", __cmds[1], "claude-ask")

reset()
__input().props.onChange("typed into the field")
__send().props.onClick()
contains("the button submits the current draft", __cmds[1], "typed into the field")

-- onSubmit hands over the live value, so Enter must not depend on onChange landing.
reset()
__input().props.onSubmit("straight from onSubmit")
contains("Enter uses the value it is handed", __cmds[1], "straight from onSubmit")

-- ── free-form text is quoted, never filtered ─────────────────────────────────
reset()
__input().props.onSubmit("what's $HOME; rm -rf ~ && echo `id`")
local c = __cmds[1]
contains("apostrophe is escaped, not stripped", c, [[what'\'']])
contains("the whole question stays inside single quotes", c, "printf %s '")
-- A substring search cannot tell quoted from unquoted, so assert the whole operand:
-- it opens with ', escapes the apostrophe as '\'', carries the rest verbatim, and
-- closes before the redirect. Nothing in it is left for the shell to interpret.
contains("the question survives verbatim inside one quoted operand", c,
  [[printf %s 'what'\''s $HOME; rm -rf ~ && echo `id`' > ]])

-- ── nothing is dispatched for nothing ────────────────────────────────────────
reset()
__input().props.onSubmit("")
expect("empty question dispatches nothing", #__cmds, 0)
reset()
__input().props.onSubmit("   \t  ")
expect("whitespace-only question dispatches nothing", #__cmds, 0)

-- ── a refused dispatch is never silent ───────────────────────────────────────
-- The panel used to close regardless of the result, so a missing noctalia CLI ate
-- the question with no toast, no answer and nothing to retry from.
reset()
__run_ok = false
__input().props.onSubmit("does this survive")
expect("a refused dispatch raises an error", #__errors, 1)
expect("and does not close the panel over it", __cmds_matching("panel-close"), 0)

reset()
__input().props.onSubmit("this one lands")
expect("a successful dispatch raises nothing", #__errors, 0)
expect("and closes the panel", __cmds_matching("panel-close"), 1)

done()
