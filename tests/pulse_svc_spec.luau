-- Spec — drives pulse-svc.luau (the headless aggregator service) through its
-- real public surfaces: the global onIpc(event, payload) reflex and the captured
-- claude.state watch callback (__watch["claude.state"]). Concatenated AFTER
-- pulse-svc.luau, so onIpc, __watch, and __state are in scope.
--
-- After each action, we read back the published claude.pulse from __state
-- and assert its schema v2 fields (top-level rollup + sessions[] array).

-- 0. Load & API assertions
expect("service defines global onIpc", type(onIpc), "function")
expect("service defines NO update function", type(update), "nil")
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

done()
