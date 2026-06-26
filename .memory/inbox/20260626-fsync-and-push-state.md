---
routed: project
topic: remember-fsync-and-push-state
date: 2026-06-26
source: noctalia-mcp session
---

Session outcome — resolves the BLOCKING "verify memd inbox writer hardening" todo
and corrects stale push state.

## fsync hardening (committed c5d03ac)
`_remember()` in `shim/noctalia-mcp.py` now fsyncs the note file before
`os.replace()` AND fsyncs the inbox dir after the rename. Closes a crash-durability
gap (power-loss/panic could land a flushed file without its dir entry = lost note,
or a renamed entry pointing at unflushed data). Atomicity vs half-written reads was
already handled by temp-write + os.replace; this adds durability only.

## BLOCKING todo RESOLVED — writers are safe-equivalent
Plugin uses `os.replace` (silent clobber on name collision); memd uses `os.link`
(fails on collision). The collision the todo worried about (multiple Claude sessions
writing the shared `~/.memory/inbox/` in parallel) is STRUCTURALLY impossible, not
just improbable: the filename embeds the PID (`{µs-ts}-{slug}-{pid}.md`), and
concurrent processes have unique PIDs, so two different shims can never collide.
Same-process same-µs collision requires concurrent writes inside ~1µs (unreachable
for a serial stdio MCP server). Decision: `os.link` parity DECLINED — no reachable
benefit, cosmetic only. Both writers are equivalent on inbox safety.

## Stale memory corrected
Memory listed `0f0a2b7` (remember fix) + `ce30ec7` (7 tools) as unpushed. They are
ALREADY on `origin/main` (pushed a prior session; `git branch -r --contains`
confirms). The blocking todo was gating an already-public push.

## Push state
Actual pending = 3 commits ahead of origin: `c5d03ac` (fsync) + 2 memd distill
commits (`c900f6e`, `e097c40`). SSH push auth is unavailable in the sandbox; USER is
pushing manually. After push, the "Push commits" todo is done.

## Still open (unchanged)
Reload plugin in noctalia (persistent subprocess — new fsync code only active after
restart); live-test context injection; live-test 4 act tools; verify remember→memd
chain end-to-end.
