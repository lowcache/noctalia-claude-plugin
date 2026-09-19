-- Test prelude — stubs noctalia.state API so pulse-svc.luau runs headless.
-- Concatenated BEFORE pulse-svc.luau (see nix/flake.nix mkRunner), so these globals
-- exist when the service's top-level state watch and initial publish execute.

__state = {}
__watch = {}
__files = {}      -- path -> contents served by readFile (the fake /proc)
__reads = {}      -- every path readFile was asked for, in order
__interval = nil  -- last setUpdateInterval value
__dirs = {}       -- dir -> list of names served by listDir
__config = {}     -- setting key -> value served by getConfig
__now = 0         -- epoch ms served by nowMs

noctalia = {
  -- Resolved from translations/en.json by tests/gen_tr_fixture.py.
  tr = __tr,
  readFile = function(path)
    __reads[#__reads + 1] = path
    local v = __files[path]
    if v == nil then return nil, "cannot open file" end
    return v
  end,
  setUpdateInterval = function(ms) __interval = ms end,
  listDir = function(dir)
    if __dirs[dir] == nil then return nil, "not a directory" end
    return __dirs[dir]
  end,
  getConfig = function(key) return __config[key] end,
  nowMs = function() return __now end,
  -- Flat objects of string/number fields only (the session files); raises on
  -- anything else, as the real decoder does on corrupt input.
  json = {
    decode = function(raw)
      if type(raw) ~= "string" or not raw:match("^%s*{.*}%s*$") then error("invalid json") end
      local t = {}
      for k, v in raw:gmatch('"([%w_]+)"%s*:%s*("?[^,"}]*"?)') do
        t[k] = v:sub(1, 1) == '"' and v:sub(2, -2) or tonumber(v)
      end
      return t
    end,
  },
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
