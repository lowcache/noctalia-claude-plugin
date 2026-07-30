-- Test prelude — stubs the noctalia panel API so sessions.luau runs headless.
-- Concatenated BEFORE sessions.luau (see nix/flake.nix mkRunner). Mirrors
-- answer_prelude, plus a runAsync recorder: the retire control's whole job is to
-- emit one exact IPC command, so the spec asserts the command string rather than
-- trusting that a button was drawn.

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

__tree = nil    -- last tree handed to panel.render
__renders = 0   -- render call count
__ticks = nil   -- last setWantsSecondTicks value
panel = {
  render = function(tree)
    __tree = tree
    __renders = __renders + 1
  end,
  setWantsSecondTicks = function(v) __ticks = v end,
}

__async = {}    -- every runAsync command, in order
__state = {}
noctalia = {
  -- Resolved from translations/en.json by tests/gen_tr_fixture.py.
  tr = __tr,
  runAsync = function(cmd)
    __async[#__async + 1] = cmd
    return true
  end,
  state = {
    get = function(key) return __state[key] end,
    set = function(key, value) __state[key] = value end,
  },
}

-- Walk the rendered tree collecting nodes of a type (depth-first, in order).
function collect(node, kind, out)
  out = out or {}
  if type(node) ~= "table" then return out end
  if node.type == kind then out[#out + 1] = node end
  for _, child in ipairs(node.children or {}) do collect(child, kind, out) end
  return out
end

-- Concatenate every label's text in the tree — the panel's visible copy.
function text_of(node)
  local parts = {}
  for _, l in ipairs(collect(node, "label")) do
    parts[#parts + 1] = tostring(l.props.text)
  end
  return table.concat(parts, "\n")
end

-- tiny assertion harness (full report, then non-zero exit via error()).
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
