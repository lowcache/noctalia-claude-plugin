-- Test prelude — stubs the noctalia panel API so answer.luau runs headless.
-- Concatenated BEFORE answer.luau (see nix/flake.nix mkRunner). The ui ctors
-- mirror the real ui prelude's node shape ({type, props, children}) so the spec
-- can walk the rendered tree; panel.render records the tree and a call count
-- for the change-guard assertions.

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

__state = {}
noctalia = {
  state = {
    get = function(key) return __state[key] end,
    set = function(key, value) __state[key] = value end,
  },
}

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
