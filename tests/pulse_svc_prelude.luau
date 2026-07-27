-- Test prelude — stubs noctalia.state API so pulse-svc.luau runs headless.
-- Concatenated BEFORE pulse-svc.luau (see nix/flake.nix mkRunner), so these globals
-- exist when the service's top-level state watch and initial publish execute.

__state = {}
__watch = {}

noctalia = {
  state = {
    watch = function(key, cb) __watch[key] = cb end,
    get = function(key) return __state[key] end,
    set = function(key, value) __state[key] = value end,
  },
}

-- Tiny assertion harness (mirrors tests/prelude.luau; kept self-contained per runner).
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
