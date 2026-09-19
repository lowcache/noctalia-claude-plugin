-- Test prelude — stubs the noctalia host so consent.luau runs headless.
-- Concatenated BEFORE consent.luau (see scripts/run-widget-specs.sh).
--
-- The panel's whole job is reading request files and dispatching shell commands, so
-- this stubs both: __files is a virtual filesystem the spec writes request tables
-- into, and __cmds records every command the panel fires.

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
__ticks = nil
panel = {
  render = function(tree)
    __tree = tree
    __renders = __renders + 1
  end,
  setWantsSecondTicks = function(v) __ticks = v end,
}

__RT = "/run/user/1000"
__files = {}  -- path -> decoded request table (see json.decode below)
__raw = {}    -- path -> literal string, for files the entry reads as text
__cmds = {}   -- every runAsync command, in order

-- readFile hands back an opaque token and json.decode maps it back to the table:
-- the entry's own "is it a string / does it decode" guards still run for real, and
-- the spec never has to hand-write JSON.
local TOKEN = "\1file\1"

__state = {}
noctalia = {
  tr = __tr,
  getenv = function(name)
    if name == "XDG_RUNTIME_DIR" then return __RT end
    if name == "XDG_STATE_HOME" then return __STATE_HOME end
    return nil
  end,
  readFile = function(path)
    if __raw[path] ~= nil then return __raw[path] end
    if __files[path] == nil then return nil end
    return TOKEN .. path
  end,
  runAsync = function(cmd)
    __cmds[#__cmds + 1] = cmd
    return true
  end,
  pluginDir = function() return "/plug dir" end, -- a catalog-style path, with a space
  notifyError = function(_s, _m) end,
  json = {
    decode = function(raw)
      if type(raw) ~= "string" then error("not a string") end
      local path = string.match(raw, "^" .. TOKEN .. "(.*)$")
      if not path then error("malformed") end
      return __files[path]
    end,
  },
  state = {
    get = function(key) return __state[key] end,
    set = function(key, value) __state[key] = value end,
  },
}

-- Spec helpers: address requests by id rather than by path.
function __req_path(id) return __RT .. "/claude-companion/consent/" .. id .. ".req" end
function __put(id, req) __files[__req_path(id)] = req end
function __drop(id) __files[__req_path(id)] = nil end
function __queue(...)
  local ids = { ... }
  __state["claude.consent"] = { id = ids[1], ids = ids, sid = "abcd1234" }
end
__STATE_HOME = "/home/u/.local/state"
function __learn_path() return __STATE_HOME .. "/noctalia/claude-companion/learn.jsonl" end
function __observations(n)
  local lines = {}
  for i = 1, n do lines[#lines + 1] = '{"key":"Bash:cmd' .. i .. '"}' end
  __raw[__learn_path()] = table.concat(lines, "\n") .. "\n"
end

function __last_cmd() return __cmds[#__cmds] end
function __cmds_matching(needle)
  local n = 0
  for _, c in ipairs(__cmds) do
    if string.find(c, needle, 1, true) then n = n + 1 end
  end
  return n
end

-- Walk the rendered tree and collect every label/button string, so a spec can ask
-- "does the panel say X" without knowing the layout.
function __texts()
  local out = {}
  local function walk(node)
    if type(node) ~= "table" then return end
    if node.props and type(node.props.text) == "string" then
      out[#out + 1] = node.props.text
    end
    for _, child in ipairs(node.children or {}) do walk(child) end
    if node.type == nil then
      for _, child in ipairs(node) do walk(child) end
    end
  end
  walk(__tree)
  return out
end
-- Position matters in an approval dialog: what is being authorised must not sit
-- below the model's own description of it.
function __index_of(needle)
  for i, t in ipairs(__texts()) do
    if string.find(t, needle, 1, true) then return i end
  end
  return -1
end

function __has_os_time() return type(os) == "table" and type(os.time) == "function" end

function __rendered()
  return table.concat(__texts(), "\n")
end
function __buttons()
  local out = {}
  local function walk(node)
    if type(node) ~= "table" then return end
    if node.type == "button" then out[#out + 1] = node end
    for _, child in ipairs(node.children or {}) do walk(child) end
    if node.type == nil then
      for _, child in ipairs(node) do walk(child) end
    end
  end
  walk(__tree)
  return out
end
function __click(label_substr)
  for _, b in ipairs(__buttons()) do
    local t = b.props and b.props.text or ""
    if string.find(t, label_substr, 1, true) and type(b.props.onClick) == "function" then
      b.props.onClick()
      return true
    end
  end
  return false
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
