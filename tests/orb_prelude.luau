-- Test prelude for the presence orb (orb.luau). Concatenated BEFORE orb.luau so
-- these globals exist when the widget's top-level setNeedsFrameTick/render and its
-- state.watch registration run. The ui.* stubs build an introspectable node tree
-- ({ type, props, children }) so a spec can walk the rendered orb and assert on the
-- disc's color/opacity and the glyph, exactly as noctalia's real ui layer would see
-- it. desktopWidget.render captures the last tree; setNeedsFrameTick records intent.

__tree = nil   -- last tree passed to desktopWidget.render
__tick = nil   -- last setNeedsFrameTick argument

desktopWidget = {
  render = function(tree) __tree = tree end,
  setNeedsFrameTick = function(b) __tick = b end,
}

-- ui.box/column/row take (props, children); ui.glyph/label take (props) only.
-- A single ctor handles both shapes — `children` is just nil for the leaf nodes.
local function ctor(t)
  return function(props, children)
    return { type = t, props = props or {}, children = children }
  end
end
ui = {
  box = ctor("box"), column = ctor("column"), row = ctor("row"),
  glyph = ctor("glyph"), label = ctor("label"), spacer = ctor("spacer"),
}

-- Depth-first search for the first node of a given type.
function find(node, t)
  if type(node) ~= "table" then return nil end
  if node.type == t then return node end
  if node.children then
    for _, c in ipairs(node.children) do
      local r = find(c, t)
      if r then return r end
    end
  end
  return nil
end

-- Capture each state.watch callback by key so the spec can push snapshots the way
-- the bar pulse's noctalia.state.set("c3.pulse", …) would.
__watch = {}
noctalia = {
  state = {
    watch = function(key, cb) __watch[key] = cb end,
    set = function() end,
  },
}

-- assertion harness (mirrors tests/prelude.luau; kept self-contained per runner).
local failures = 0
function expect(label, got, want)
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s\n  got : %q\n  want: %q", label, tostring(got), tostring(want)))
  else
    print("ok   " .. label)
  end
end
function near(label, got, want, eps)
  eps = eps or 1e-6
  if type(got) == "number" and math.abs(got - want) <= eps then
    print("ok   " .. label)
  else
    failures = failures + 1
    print(string.format("FAIL %s\n  got : %s\n  want: ~%s", label, tostring(got), tostring(want)))
  end
end
function between(label, got, lo, hi)
  if type(got) == "number" and got >= lo - 1e-9 and got <= hi + 1e-9 then
    print("ok   " .. label)
  else
    failures = failures + 1
    print(string.format("FAIL %s\n  got : %s\n  want: [%s,%s]", label, tostring(got), tostring(lo), tostring(hi)))
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
function done()
  if failures > 0 then error(failures .. " test failure(s)", 0) end
  print("all specs passed")
end
