-- Test prelude — stubs the noctalia widget API so pulse.luau runs headless.
-- Concatenated BEFORE pulse.luau (see nix/flake.nix mkRunner), so these globals
-- exist when the widget's top-level state watch and initial render execute.
-- The stubs record the last applied glyph/color/tooltip for the spec to assert on.

__tt = nil
__glyph = nil
__color = nil

barWidget = {
  setGlyph = function(g) __glyph = g end,
  setGlyphColor = function(c) __color = c end,
  setTooltip = function(t) __tt = t end,
}

-- Capture state.watch callbacks by key so the spec can push snapshots to the widget
-- (e.g. __watch["claude.pulse"](snap)), mirroring production where the aggregator
-- service (pulse-svc.luau) publishes to noctalia.state.
__config = {}
__state = {}
__watch = {}
noctalia = {
  -- Resolved from translations/en.json by tests/gen_tr_fixture.py.
  tr = __tr,
  getConfig = function(k) return __config[k] end,
  state = {
    watch = function(key, cb) __watch[key] = cb end,
    get = function(key) return __state[key] end,
    set = function(key, value) __state[key] = value end,
  },
  setUpdateInterval = function(_ms) end,
  readFile = function(_path) return nil, "stub" end,
  expandPath = function(p) return p end,
  getenv = function(_name) return nil end,
  isDarkMode = function() return true end,
  string = { urlEncode = function(s) return s end },
  json = { decode = function(_s) return nil end },
  runAsync = function(_cmd) return true end,
  notifyError = function(_src, _msg) end,
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
