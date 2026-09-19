-- Spec — drives pulse-svc.luau (the headless aggregator service) through its
-- real public surfaces: the global onIpc(event, payload) reflex and the captured
-- claude.state watch callback (__watch["claude.state"]). Concatenated AFTER
-- pulse-svc.luau, so onIpc, __watch, and __state are in scope.
--
-- After each action, we read back the published claude.pulse from __state
-- and assert its schema v2 fields (top-level rollup + sessions[] array).

-- 0. Load & API assertions
expect("service defines global onIpc", type(onIpc), "function")
expect("service defines the liveness sweep", type(update), "function")
expect("sweep runs every 5 s, not the 1 s default", __interval, 5000)
expect("service subscribes to claude.state watch", type(__watch["claude.state"]), "function")

local snap = __state["claude.pulse"]
expect("load → count is 0", snap.count, 0)
expect("load → state is idle", snap.state, "idle")
expect("load → model is ?", snap.model, "?")
expect("load → tin is 0", snap.tin, 0)
expect("load → tout is 0", snap.tout, 0)
expect("load → cr is 0", snap.cr, 0)
expect("load → sessions empty", #snap.sessions, 0)

-- 1. Single session lifecycle + telemetry math (tin = in + cacheCreate)
onIpc("idle", "opus-4-8,100,50,0,0,alpha")
snap = __state["claude.pulse"]
expect("single session idle → count", snap.count, 1)
expect("single session idle → state", snap.state, "idle")
expect("single session idle → model", snap.model, "opus-4-8")
expect("single session idle → tin", snap.tin, 100)
expect("single session idle → tout", snap.tout, 50)
expect("single session idle → cr", snap.cr, 0)
expect("single session idle → sessions[1].sid", snap.sessions[1].sid, "alpha")
expect("single session idle → sessions[1].state", snap.sessions[1].state, "idle")

onIpc("turn_start", "opus-4-8,200,80,500,1000,alpha")
snap = __state["claude.pulse"]
expect("turn_start → state", snap.state, "turn_start")
expect("turn_start → tin = in + cacheCreate (200 + 500)", snap.tin, 700)
expect("turn_start → tout", snap.tout, 80)
expect("turn_start → cr", snap.cr, 1000)
expect("turn_start → sessions[1].sid", snap.sessions[1].sid, "alpha")
expect("turn_start → sessions[1].state", snap.sessions[1].state, "turn_start")
expect("turn_start → sessions[1].tin", snap.sessions[1].tin, 700)
expect("turn_start → sessions[1].tout", snap.sessions[1].tout, 80)
expect("turn_start → sessions[1].cr", snap.sessions[1].cr, 1000)

onIpc("tool_start", "opus-4-8,250,120,500,2000,alpha")
snap = __state["claude.pulse"]
expect("tool_start → state", snap.state, "tool_start")
expect("tool_start → tin (250 + 500)", snap.tin, 750)
expect("tool_start → tout", snap.tout, 120)
expect("tool_start → cr", snap.cr, 2000)

onIpc("turn_end", "opus-4-8,250,150,500,2000,alpha")
snap = __state["claude.pulse"]
expect("turn_end → state", snap.state, "turn_end")
expect("turn_end → tin", snap.tin, 750)
expect("turn_end → tout", snap.tout, 150)
expect("turn_end → cr", snap.cr, 2000)

-- 2. Multi-session priority & schema v2 top-level burn rules
-- alpha is currently in turn_end (prio 2) with tin=750, tout=150
onIpc("needs_attention", "haiku-4-5,100,20,50,0,beta")
snap = __state["claude.pulse"]
expect("2 sessions → state is needs_attention (prio 6 > 2)", snap.state, "needs_attention")
expect("2 sessions → count is 2", snap.count, 2)
expect("2 sessions → top-level model is ? when count > 1", snap.model, "?")
expect("2 sessions → Sigma tin (750 + 150)", snap.tin, 900)
expect("2 sessions → Sigma tout (150 + 20)", snap.tout, 170)
expect("2 sessions → cr is 0 when count > 1", snap.cr, 0)
expect("2 sessions → sessions[] has 2 entries", #snap.sessions, 2)
expect("2 sessions → sessions[1].sid is beta (most recent)", snap.sessions[1].sid, "beta")
expect("2 sessions → sessions[1].state", snap.sessions[1].state, "needs_attention")
expect("2 sessions → sessions[1].tin (100 + 50)", snap.sessions[1].tin, 150)
expect("2 sessions → sessions[2].sid is alpha", snap.sessions[2].sid, "alpha")
expect("2 sessions → sessions[2].state", snap.sessions[2].state, "turn_end")

-- 3. session_end retires a sid
onIpc("session_end", "opus-4-8,0,0,0,0,alpha")
snap = __state["claude.pulse"]
expect("session_end alpha → count is 1", snap.count, 1)
expect("session_end alpha → state remains needs_attention", snap.state, "needs_attention")
expect("session_end alpha → top-level model reverts to haiku-4-5", snap.model, "haiku-4-5")
expect("session_end alpha → tin is 150", snap.tin, 150)
expect("session_end alpha → tout is 20", snap.tout, 20)
expect("session_end alpha → sessions[] has 1 entry", #snap.sessions, 1)
expect("session_end alpha → sessions[1].sid is beta", snap.sessions[1].sid, "beta")

onIpc("session_end", "haiku-4-5,0,0,0,0,beta")
snap = __state["claude.pulse"]
expect("all ended → count 0", snap.count, 0)
expect("all ended → state idle", snap.state, "idle")
expect("all ended → sessions empty", #snap.sessions, 0)

-- 4. Default-slot MANUAL_REST — bare idle / turn_end / error retires default slot
onIpc("needs_attention", "")
snap = __state["claude.pulse"]
expect("payload-less poke → count 1", snap.count, 1)
expect("payload-less poke → state needs_attention", snap.state, "needs_attention")
expect("payload-less poke → sid is default", snap.sessions[1].sid, "default")

onIpc("idle", "")
snap = __state["claude.pulse"]
expect("bare idle retires default slot → count 0", snap.count, 0)
expect("bare idle retires default slot → state idle", snap.state, "idle")
expect("bare idle retires default slot → sessions empty", #snap.sessions, 0)

onIpc("needs_attention", "")
onIpc("turn_end", "")
snap = __state["claude.pulse"]
expect("bare turn_end also retires default slot → count 0", snap.count, 0)

onIpc("needs_attention", "")
onIpc("error", "")
snap = __state["claude.pulse"]
expect("bare error also retires default slot → count 0", snap.count, 0)

-- Real session is NOT retired by resting states; only session_end retires it
onIpc("idle", "opus-4-8,10,20,0,0,real_sid")
snap = __state["claude.pulse"]
expect("real session idle is NOT retired", snap.count, 1)
onIpc("session_end", "opus-4-8,0,0,0,0,real_sid")
snap = __state["claude.pulse"]
expect("real session retired on session_end", snap.count, 0)

-- 5. Quick-ask (claude.state watch feed)
__watch["claude.state"]("turn_start")
snap = __state["claude.pulse"]
expect("quick-ask turn_start → count 1", snap.count, 1)
expect("quick-ask turn_start → state turn_start", snap.state, "turn_start")
expect("quick-ask turn_start → sid is ask", snap.sessions[1].sid, "ask")
expect("quick-ask turn_start → tin is 0", snap.tin, 0)

__watch["claude.state"]("turn_end")
snap = __state["claude.pulse"]
expect("quick-ask turn_end drops ask session → count 0", snap.count, 0)
expect("quick-ask turn_end → state idle", snap.state, "idle")

__watch["claude.state"]("text")
expect("quick-ask text → count 1", __state["claude.pulse"].count, 1)
__watch["claude.state"]("error")
expect("quick-ask error drops ask session → count 0", __state["claude.pulse"].count, 0)

-- Quick-ask priority combined with a real session
onIpc("tool_start", "opus-4-8,100,50,0,0,gamma")
__watch["claude.state"]("needs_attention")
snap = __state["claude.pulse"]
expect("quick-ask needs_attention outranks tool_start", snap.state, "needs_attention")
expect("real session + ask → count 2", snap.count, 2)

__watch["claude.state"](nil)
snap = __state["claude.pulse"]
expect("nil drops ask session → count 1", snap.count, 1)
expect("reverts to tool_start after ask dropped", snap.state, "tool_start")
onIpc("session_end", "opus-4-8,0,0,0,0,gamma")
expect("all sessions cleared after gamma session_end", __state["claude.pulse"].count, 0)

-- ── consent request queue ────────────────────────────────────────────────────
-- Claude issues tool calls in parallel, so consent requests arrive in batches. The
-- slot this used to be dropped every request but the newest, leaving the rest with
-- no surface until their deadlines expired.
-- Report a missing queue as a failed expectation rather than an indexing crash, so
-- the suite says which contract broke instead of dying on a nil.
local function qlen()
  local q = __state["claude.consent"]
  if type(q) ~= "table" or type(q.ids) ~= "table" then return -1 end
  return #q.ids
end

__state["claude.consent"] = nil
onIpc("consent_request", "reqA,alpha")
expect("first request is the head", __state["claude.consent"].id, "reqA")
expect("queue has one", qlen(), 1)

onIpc("consent_request", "reqB,alpha")
local q = __state["claude.consent"]
expect("second request does not evict the first", q.id, "reqA")
expect("queue has both", qlen(), 2)
expect("oldest first", q.ids[1], "reqA")
expect("newest last", q.ids[2], "reqB")

-- A re-dispatch of the same id must not queue it twice.
onIpc("consent_request", "reqA,alpha")
q = __state["claude.consent"]
expect("re-dispatch does not duplicate", qlen(), 2)

-- Bounded: a runaway producer must not grow this without limit.
for i = 1, 40 do onIpc("consent_request", "flood" .. i .. ",alpha") end
expect("queue is bounded", qlen(), 16)

-- An id-less payload is ignored rather than queued as an empty entry.
local before = qlen()
onIpc("consent_request", ",alpha")
expect("empty id is ignored", qlen(), before)

-- 9. Liveness: a pid-tagged session is retired once its Claude process is gone.
-- /proc/<pid>/stat: starttime is field 22, counted from the LAST ')'.
local function stat(pid, start, comm)
  return pid .. " (" .. (comm or ".claude-wrapped") .. ") S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 " .. start .. " 23 24\n"
end
local function has(sid)
  for _, s in ipairs(__state["claude.pulse"].sessions) do
    if s.sid == sid then return true end
  end
  return false
end

__files["/proc/4242/stat"] = stat(4242, "1000")
__files["/proc/4343/stat"] = stat(4343, "2000", "we (ird) name")
onIpc("turn_start", "opus-5,1,1,0,0,live1,4242")
onIpc("turn_start", "opus-5,1,1,0,0,dead1,4343")
onIpc("turn_start", "opus-5,1,1,0,0,nopid1")
onIpc("turn_start", "opus-5,1,1,0,0,unseen1,4444") -- no /proc entry at first sight

local snap0 = __state["claude.pulse"]
update()
expect("a tick with every process alive publishes nothing", __state["claude.pulse"], snap0)

__files["/proc/4343/stat"] = nil
update()
expect("dead process -> session retired", has("dead1"), false)
expect("live session kept", has("live1"), true)
expect("session without a pid is never swept", has("nopid1"), true)
expect("pid unreadable at first sight is never swept", has("unseen1"), true)

__files["/proc/4242/stat"] = stat(4242, "9999")
update()
expect("reused pid (new start time) -> session retired", has("live1"), false)

-- a pid that was unreadable at first sight must not arm the sweep when a process
-- later shows up under that number
__files["/proc/4444/stat"] = stat(4444, "7")
update()
expect("a pid seen only later does not retire the session", has("unseen1"), true)

-- pid reuse is still caught when comm holds ") " (field counting from the last ')')
__files["/proc/4545/stat"] = stat(4545, "500", "a) b (c")
onIpc("turn_start", "opus-5,1,1,0,0,odd1,4545")
update()
expect("odd comm, same process -> kept", has("odd1"), true)
__files["/proc/4545/stat"] = stat(4545, "501", "a) b (c")
update()
expect("odd comm, reused pid -> retired", has("odd1"), false)

-- claude --resume brings the same session back in a new process
__files["/proc/5000/stat"] = stat(5000, "300")
__files["/proc/5001/stat"] = stat(5001, "301")
onIpc("idle", "opus-5,1,1,0,0,res1,5000")
onIpc("turn_start", "opus-5,1,1,0,0,res1,5001")
__files["/proc/5000/stat"] = nil
update()
expect("resumed session follows its new process", has("res1"), true)

__reads = {}
onIpc("idle", "opus-5,1,1,0,0,evil1,../../etc/passwd")
onIpc("idle", "opus-5,1,1,0,0,evil2,123456789012")
update()
local read_log = table.concat(__reads, "\n")
contains("the sweep did read procfs", read_log, "/proc/5001/stat")
absent("a non-numeric pid never reaches a path", read_log, "..")
absent("an oversized pid is not read", read_log, "123456789012")
expect("hostile-pid sessions are still tracked", has("evil1") and has("evil2"), true)

-- 10. Hookless detection from <config>/sessions/<pid>.json
local DIR = "~/.claude/sessions"
local function sfile(sid, extra)
  return '{"sessionId":"' .. sid .. '","kind":"interactive","entrypoint":"cli"' .. (extra or "") .. "}"
end
local function row(sid)
  for _, s in ipairs(__state["claude.pulse"].sessions) do
    if s.sid == sid then return s end
  end
  return nil
end
__dirs[DIR] = { "7001.json", "7002.json", "7003.json", "7004.json", "7005.json", "7006.json",
  "7007.json", "7008.json", "7011.json", "notes.txt", "123456789.json" }
__files["/proc/7011/stat"] = stat(7011, "100")
__files[DIR .. "/7011.json"] = sfile("kkk11111-x", ',"status":"busy"') -- no procStart: identity unprovable
__files["/proc/7001/stat"] = stat(7001, "100")
__files["/proc/7002/stat"] = stat(7002, "100")
__files["/proc/7003/stat"] = stat(7003, "100")
__files["/proc/7005/stat"] = stat(7005, "999")
__files["/proc/7006/stat"] = stat(7006, "100")
__files["/proc/7007/stat"] = stat(7007, "100")
__files["/proc/7008/stat"] = stat(7008, "100")
__files[DIR .. "/7001.json"] = sfile("aaa11111-x-y", ',"procStart":"100","status":"busy"')
__files[DIR .. "/7002.json"] = sfile("bbb22222-x-y", ',"procStart":"100","status":"waiting"')
__files[DIR .. "/7003.json"] = '{"sessionId":"ccc33333-x","kind":"interactive","entrypoint":"sdk-cli","status":"busy"}'
__files[DIR .. "/7004.json"] = sfile("ddd44444-x", ',"status":"busy"') -- no /proc entry: SIGKILLed
__files[DIR .. "/7005.json"] = sfile("eee55555-x", ',"procStart":"100","status":"busy"') -- pid reused
__files[DIR .. "/7006.json"] = '{"sessionId":"fff66666-x","kind":"bg","status":"busy"}'
__files[DIR .. "/7007.json"] = "{not json"
__files[DIR .. "/7008.json"] = sfile("ggg77777-x", ',"procStart":"100"') -- older Claude Code: no status field
update()
expect("busy file -> detected as working", row("aaa11111") and row("aaa11111").state, "turn_start")
expect("detected session is flagged hookless", row("aaa11111") and row("aaa11111").nohooks, true)
expect("waiting file -> needs_attention", row("bbb22222") and row("bbb22222").state, "needs_attention")
expect("claude -p / SDK sessions are skipped", row("ccc33333"), nil)
expect("a file whose process is gone is skipped", row("ddd44444"), nil)
expect("a file whose pid was reused is skipped", row("eee55555"), nil)
expect("non-interactive kinds are skipped", row("fff66666"), nil)
expect("no status field -> idle", row("ggg77777") and row("ggg77777").state, "idle")
expect("a file without procStart is skipped", row("kkk11111"), nil)
expect("rollup picks up the detected needs-you", __state["claude.pulse"].state, "needs_attention")

local snap1 = __state["claude.pulse"]
update()
expect("an unchanged scan publishes nothing", __state["claude.pulse"], snap1)

__files[DIR .. "/7002.json"] = sfile("bbb22222-x-y", ',"procStart":"100","status":"idle"')
update()
expect("file status drives a hookless session", row("bbb22222").state, "idle")

-- a hook event takes over: hooks win, the flag drops, file status stops mattering
onIpc("tool_start", "opus-5,5,5,0,0,aaa11111")
expect("hooked session loses the hookless flag", row("aaa11111").nohooks, nil)
__files[DIR .. "/7001.json"] = sfile("aaa11111-x-y", ',"procStart":"100","status":"idle"')
update()
expect("file status no longer overrides a hooked session", row("aaa11111").state, "tool_start")
-- and the pid from the file arms liveness for a hook that sent none
__files["/proc/7001/stat"] = nil
update()
expect("pid-less hooked session retired once its detected process dies", row("aaa11111"), nil)

-- hooked first with no pid (older hooks), detected later: the file's pid arms liveness
onIpc("idle", "opus-5,1,1,0,0,hhh88888")
__files["/proc/7009/stat"] = stat(7009, "100")
__files[DIR .. "/7009.json"] = sfile("hhh88888-x", ',"procStart":"100","status":"idle"')
table.insert(__dirs[DIR], "7009.json")
update()
expect("hooked session is not flagged hookless when detected", row("hhh88888").nohooks, nil)
__files["/proc/7009/stat"] = nil
update()
expect("detection arms liveness for a pid-less hooked session", row("hhh88888"), nil)

-- clean exit: file gone -> a detection-only session goes with it
__files[DIR .. "/7008.json"] = nil
for i, n in ipairs(__dirs[DIR]) do
  if n == "7008.json" then table.remove(__dirs[DIR], i) break end
end
update()
expect("detection-only session retires when its file goes", row("ggg77777"), nil)

-- session_end while the exiting process still has its file: not re-detected
onIpc("session_end", ",,,,,bbb22222")
update()
expect("an ended session is not re-detected while it exits", row("bbb22222"), nil)
-- resumed in a new process while the old file is still around (the Retire-then-resume path)
__files["/proc/7010/stat"] = stat(7010, "200") -- started after the ended one
__files[DIR .. "/7010.json"] = sfile("bbb22222-x-y", ',"procStart":"200","status":"busy"')
local saved_dir = __dirs[DIR]
__dirs[DIR] = { "7010.json", "7002.json" }
update()
update()
expect("a resume in a new process is detected despite the ended flag", row("bbb22222") and row("bbb22222").state, "turn_start")
onIpc("session_end", ",,,,,bbb22222")
__files[DIR .. "/7010.json"] = nil
__dirs[DIR] = saved_dir
__dirs[DIR] = { "7001.json" }
update()
__dirs[DIR] = { "7001.json", "7002.json" }
update()
expect("the same session resumed later is detected again", row("bbb22222") ~= nil, true)

__config["detect_sessions"] = false
update()
expect("turning detection off drops detection-only sessions", row("bbb22222"), nil)
__config["detect_sessions"] = nil

-- 11. Newest signal wins: a file status written after the last hook event corrects
-- what hooks never report. Hook times come from nowMs, file times from statusUpdatedAt.
__files["/proc/7020/stat"] = stat(7020, "100")
local function zfile(status, at)
  __files[DIR .. "/7020.json"] = sfile("zzz99999-x", ',"procStart":"100","status":"' .. status .. '"'
    .. (at and (',"statusUpdatedAt":' .. at) or ""))
end
__dirs[DIR] = { "7020.json" }
__now = 1000
onIpc("tool_start", "opus-5,1,1,0,0,zzz99999")
zfile("idle", 900)
update()
expect("a file status older than the last hook is ignored", row("zzz99999").state, "tool_start")
zfile("idle", 2000)
update()
expect("Esc interrupt: newer idle file ends a stuck working state", row("zzz99999").state, "idle")
expect("the corrected session stays hooked", row("zzz99999").nohooks, nil)

__now = 3000
onIpc("turn_start", "opus-5,1,1,0,0,zzz99999")
update()
expect("a newer hook beats the older idle file", row("zzz99999").state, "turn_start")

onIpc("tool_start", "opus-5,1,1,0,0,zzz99999")
zfile("waiting", 4000)
update()
expect("a question pending behind a tool call -> needs you", row("zzz99999").state, "needs_attention")

__now = 5000
onIpc("tool_start", "opus-5,1,1,0,0,zzz99999")
zfile("busy", 6000)
update()
expect("same class keeps the hook's detail (tool, not thinking)", row("zzz99999").state, "tool_start")

__now = 7000
onIpc("turn_end", "opus-5,1,1,0,0,zzz99999")
zfile("idle", 8000)
update()
expect("resting stays turn_end when the file says idle", row("zzz99999").state, "turn_end")

__now = 9000
onIpc("tool_start", "opus-5,1,1,0,0,zzz99999")
zfile("idle", nil)
update()
expect("no statusUpdatedAt -> no correction", row("zzz99999").state, "tool_start")

zfile("idle", 10000)
__config["detect_sessions"] = false
update()
expect("detection off -> no correction either", row("zzz99999").state, "tool_start")
__config["detect_sessions"] = nil

done()
