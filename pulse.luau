-- The attention pulse (bar widget) — a glanceable live readout of Claude across
-- ALL active sessions. Two feeds converge on the session table:
--   • Claude Code hooks fire the plugin-dispatch IPC → onIpc here (the reflex):
--       noctalia msg plugin lowcache/claude:pulse all <event> [payload]
--     payload = "model,in,out,cacheCreate,cacheRead,session" (hooks/pulse.py).
--     Each real session is tracked by its id; SessionEnd removes it.
--   • cc.luau writes "cc.state" (the launcher quick-ask) → watched here as one
--     ephemeral pseudo-session ("ask"), removed when the ask completes.
--
-- Bar widgets do DISCRETE state (glyph/color/tooltip), not per-frame animation.
-- The bar API is the `barWidget.*` table (NOT `widget`). Glyph names are Tabler
-- icon names; an unknown name renders the skull fallback.
-- The smooth breathing "wow" lives in the companion presence orb (orb.luau, a
-- [[desktop_widget]] with setNeedsFrameTick/onFrameTick). The orb is a pure view:
-- this bar dot mirrors its session rollup to noctalia.state ("cc.pulse", at the end
-- of render below) and the orb subscribes — same state map, two surfaces.

-- Colors use only the global scheme's accents so the dot matches the other bar
-- widgets: `secondary` (the green accent) for the ambient/working states (idle,
-- tool), `primary` (orange) for the Claude-active states (thinking/responding/
-- done), and `error` (red) reserved for the attention bell + hard errors.
local VISUAL = {
  idle            = { glyph = "robot",          color = "secondary", tip = "Claude: idle" },
  turn_start      = { glyph = "brain",          color = "primary",   tip = "Claude: thinking" },
  text            = { glyph = "message-dots",   color = "primary",   tip = "Claude: responding" },
  tool_start      = { glyph = "tool",           color = "secondary", tip = "Claude: running a tool" },
  needs_attention = { glyph = "bell-ringing",   color = "error",     tip = "Claude needs you" },
  turn_end        = { glyph = "bell",           color = "primary",   tip = "Claude: done — ready for you" },
  error           = { glyph = "alert-triangle", color = "error",     tip = "Claude: error" },
}

-- With several sessions in different states, the bar shows the most urgent one:
-- a session that needs you outranks one merely working, which outranks one idle.
local STATE_PRIO = {
  needs_attention = 6, error = 5, tool_start = 4,
  turn_start = 3, text = 3, turn_end = 2, idle = 1,
}
-- Compact per-session words for the multi-session tooltip.
local STATE_WORD = {
  idle = "idle", turn_start = "thinking", text = "responding",
  tool_start = "tool", needs_attention = "needs you",
  turn_end = "done", error = "error",
}

-- sid -> { sid, state, model, tin, tout, cr, seq }. `seq` is a monotonic counter
-- (no os.time dependency in the widget sandbox) used to order by recency.
local sessions = {}
local seq = 0

local function split(s, sep)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
  return out
end

local function kfmt(s)
  local n = tonumber(s) or 0
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1000 then return string.format("%.1fk", n / 1000) end
  return tostring(math.floor(n))
end

-- "model,in,out,cacheCreate,cacheRead,session" -> a session delta, or nil. "in"
-- (fresh prompt tokens) is tiny next to cache reads, so the displayed input is
-- fresh + cache-create (full-rate work); cache reads are tracked separately.
local function parse_payload(tel)
  if not tel or tel == "" then return nil end
  local f = split(tel, ",")
  local sid = f[6]
  if not sid or sid == "" then return nil end
  return {
    sid = sid,
    model = (f[1] and f[1] ~= "") and f[1] or "?",
    tin = (tonumber(f[2]) or 0) + (tonumber(f[4]) or 0),
    tout = tonumber(f[3]) or 0,
    cr = tonumber(f[5]) or 0,
  }
end

local function has_burn(s)
  return s.model and s.model ~= "?" and ((s.tin or 0) + (s.tout or 0)) > 0
end

local function burn_line(s)
  local l = string.format("%s · %s in / %s out", s.model, kfmt(s.tin), kfmt(s.tout))
  if (s.cr or 0) > 0 then l = l .. " · " .. kfmt(s.cr) .. " cached" end
  return l
end

local function ordered()
  local arr = {}
  for _, s in pairs(sessions) do arr[#arr + 1] = s end
  table.sort(arr, function(a, b) return (a.seq or 0) > (b.seq or 0) end)
  return arr
end

local function render()
  local arr = ordered()
  local count = #arr

  local best, bestp = "idle", 0
  for _, s in ipairs(arr) do
    local p = STATE_PRIO[s.state] or 0
    if p > bestp then bestp = p; best = s.state end
  end
  local v = VISUAL[best] or VISUAL.idle
  barWidget.setGlyph(v.glyph)
  barWidget.setGlyphColor(v.color)

  local tip
  if count == 0 then
    tip = VISUAL.idle.tip
  elseif count == 1 then
    local s = arr[1]
    local sv = VISUAL[s.state] or VISUAL.idle
    tip = has_burn(s) and (sv.tip .. "\n" .. burn_line(s)) or sv.tip
  else
    local lines = { string.format("Claude — %d sessions", count) }
    local Tin, Tout = 0, 0
    for _, s in ipairs(arr) do
      local line = s.sid .. " · " .. (STATE_WORD[s.state] or s.state)
      if has_burn(s) then
        line = line .. " · " .. s.model .. " " .. kfmt(s.tin) .. "/" .. kfmt(s.tout)
        Tin = Tin + s.tin; Tout = Tout + s.tout
      end
      lines[#lines + 1] = line
    end
    if (Tin + Tout) > 0 then
      lines[#lines + 1] = string.format("Σ %s in / %s out", kfmt(Tin), kfmt(Tout))
    end
    tip = table.concat(lines, "\n")
  end
  barWidget.setTooltip(tip)

  -- Mirror the rollup to shared state so the presence orb (orb.luau, a separate
  -- desktop widget) renders the same status without re-deriving it. The bar dot
  -- stays the single place that aggregates sessions; the orb is a pure subscriber.
  -- Snapshot carries only what the orb needs: the most-urgent state, the session
  -- count, and burn totals (single-session figures when count==1, the sum when >1).
  local snap = { state = best, count = count, model = "?", tin = 0, tout = 0, cr = 0 }
  if count == 1 and has_burn(arr[1]) then
    local s = arr[1]
    snap.model, snap.tin, snap.tout, snap.cr = s.model, s.tin, s.tout, s.cr
  elseif count > 1 then
    local Tin, Tout = 0, 0
    for _, s in ipairs(arr) do
      if has_burn(s) then Tin = Tin + s.tin; Tout = Tout + s.tout end
    end
    snap.tin, snap.tout = Tin, Tout
  end
  noctalia.state.set("cc.pulse", snap)
end

local function touch(sid, state, p)
  seq = seq + 1
  local s = sessions[sid] or { sid = sid }
  s.state = state
  s.seq = seq
  if p then
    s.model, s.tin, s.tout, s.cr = p.model, p.tin, p.tout, p.cr
  end
  sessions[sid] = s
end

-- launcher quick-ask path (no session id, no telemetry). Ephemeral: shown while
-- streaming, dropped when it finishes — the answer is delivered via notify, so a
-- lingering "done" would only inflate the session count.
noctalia.state.watch("cc.state", function(s)
  if type(s) ~= "string" then return end
  if s == "turn_end" or s == "error" then
    sessions["ask"] = nil
  else
    touch("ask", s, nil)
  end
  render()
end)

-- hook reflex path: per-session state + token telemetry, full lifecycle. The
-- dispatcher always tags the event with a session id; `session_end` (the Claude
-- Code SessionEnd hook) retires the session so stale entries never accumulate.
--
-- A payload-less event carries no session id (real hook events always do) — only a
-- manual `noctalia msg … :pulse all <event>` poke from the CLI does. Those land in a
-- single "default" test slot. To keep such a poke from leaving a sticky phantom
-- session, any RESTING state (idle / turn_end / error) retires "default" too — so
-- `… all idle` cleanly clears the orb after a manual test, without a plugin reload.
local MANUAL_REST = { idle = true, turn_end = true, error = true }
function onIpc(event, payload)
  if type(event) ~= "string" then return end
  local p = parse_payload(payload)
  local sid = (p and p.sid) or "default"
  if event == "session_end" or (sid == "default" and MANUAL_REST[event]) then
    sessions[sid] = nil
  else
    touch(sid, event, p)
  end
  render()
end

render()
