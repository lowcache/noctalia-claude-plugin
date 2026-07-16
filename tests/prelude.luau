-- Test prelude — stubs the noctalia widget API so pulse.luau runs headless.
-- Concatenated BEFORE pulse.luau (see nix/flake.nix mkRunner), so these globals
-- exist when the widget's top-level apply("idle") and onIpc definition execute.
-- The stubs record the last applied glyph/color/tooltip for the spec to assert on.

__tt = nil
__glyph = nil
__color = nil

barWidget = {
  setGlyph = function(g) __glyph = g end,
  setGlyphColor = function(c) __color = c end,
  setTooltip = function(t) __tt = t end,
}

-- watch() is invoked at load with ("claude.state", callback); capture the callback
-- so the spec can drive the quick-ask path the same way noctalia.state.set would.
-- set() records the last published snapshot per key (__state) so a spec can assert
-- on what the bar pulse mirrors to the presence orb ("claude.pulse").
__watch_cb = nil
__state = {}
noctalia = {
  state = {
    watch = function(_key, cb) __watch_cb = cb end,
    set = function(key, value) __state[key] = value end,
  },
  -- breath timer + palette resolution stubs. readFile returning nil makes the
  -- widget keep its fallback accents, so spec color expectations are fixed hex.
  setUpdateInterval = function(_ms) end,
  readFile = function(_path) return nil, "stub" end,
  expandPath = function(p) return p end,
  getenv = function(_name) return nil end,
  isDarkMode = function() return true end,
  string = { urlEncode = function(s) return s end },
  json = { decode = function(_s) return nil end },
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
