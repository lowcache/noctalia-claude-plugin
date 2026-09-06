-- Test prelude — stubs the noctalia host so ask.luau runs headless.
-- Concatenated BEFORE ask.luau (see scripts/run-widget-specs.sh).
--
-- The panel's job is to get one line of free-form text onto a shell command safely,
-- so the stubs that matter are runAsync (recorded, with a settable return) and
-- notifyError (recorded): a question that fails to dispatch must not vanish quietly.

local function ctor(t)
  return function(props, children)
    return { type = t, props = props or {}, children = children or {} }
  end
end

ui = {
  column = ctor("column"), row = ctor("row"), box = ctor("box"),
  label = ctor("label"), glyph = ctor("glyph"), image = ctor("image"),
  separator = ctor("separator"), spacer = ctor("spacer"),
  progress = ctor("progress"), button = ctor("button"), graph = ctor("graph"),
  input = ctor("input"), select = ctor("select"), slider = ctor("slider"),
  toggle = ctor("toggle"), scroll = ctor("scroll"),
}

__tree = nil
__renders = 0
panel = {
  render = function(tree)
    __tree = tree
    __renders = __renders + 1
  end,
  setWantsSecondTicks = function(v) __ticks = v end,
}

__RT = "/run/user/1000"
__cmds = {}
__errors = {}
__run_ok = true -- flip to model a dispatch the host could not launch

noctalia = {
  tr = __tr,
  getenv = function(name)
    if name == "XDG_RUNTIME_DIR" then return __RT end
    return nil
  end,
  runAsync = function(cmd)
    __cmds[#__cmds + 1] = cmd
    return __run_ok
  end,
  notifyError = function(_src, msg) __errors[#__errors + 1] = msg end,
  state = { get = function() return nil end, set = function() end },
}

function __find(node, kind)
  if type(node) ~= "table" then return nil end
  if node.type == kind then return node end
  for _, child in ipairs(node.children or {}) do
    local hit = __find(child, kind)
    if hit then return hit end
  end
  return nil
end
function __input() return __find(__tree, "input") end
function __send() return __find(__tree, "button") end
function __last_cmd() return __cmds[#__cmds] end
function __cmds_matching(needle)
  local n = 0
  for _, c in ipairs(__cmds) do
    if string.find(c, needle, 1, true) then n = n + 1 end
  end
  return n
end

local failures = 0
function expect(label, got, want)
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s\n  got : %q\n  want: %q", label, tostring(got), tostring(want)))
  else
    print("ok   " .. label)
  end
end
function contains(label, haystack, needle)
  if type(haystack) == "string" and string.find(haystack, needle, 1, true) then
    print("ok   " .. label)
  else
    failures = failures + 1
    print(string.format("FAIL %s\n  %q\n  has no: %q", label, tostring(haystack), tostring(needle)))
  end
end
function absent(label, haystack, needle)
  if type(haystack) == "string" and string.find(haystack, needle, 1, true) then
    failures = failures + 1
    print(string.format("FAIL %s\n  %q\n  unexpectedly has: %q", label, tostring(haystack), tostring(needle)))
  else
    print("ok   " .. label)
  end
end
function done()
  if failures > 0 then error(failures .. " test failure(s)", 0) end
  print("all specs passed")
end
