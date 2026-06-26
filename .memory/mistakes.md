---
type: mistakes
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Mistake Audit Log (append-only)

_No mistakes recorded yet._

### 2026-06-26 — MCP shim & launcher hardening
Review of `shim/noctalia-mcp.py` and launcher found 6 issues; all fixed and verified:
- 2 HIGH crash vectors in MCP shim (untrusted JSON-RPC stdin).
- 1 MED schema issue.
- 3 `cc.luau` enhancements: `parse()` now accumulates assistant text across chunks (reliable `/cc ?` answers); bare `/cc ?` shows hint instead of launching task "?"; `user` messages reset pulse off tool icon.

Verification: adversarial MCP sequence (garbage JSON, non-dict, non-string args, unknown tool) — server survived, returned proper error objects (rc=0). Launcher loads cleanly on reload (no luau errors).

Lesson: shim is untrusted-input boundary (stdin JSON-RPC) — validate types/shape, return error objects, never assume dict/str.

### 2026-06-26 — remember tool: second-resolution filename collision + non-atomic write
**Symptom:** Two concurrent Claude sessions (each spawning their own shim subprocess) calling `remember` within the same second produce files with identical names (`{YYYYMMDD-HHMMSS}-{slug}.md`), causing one note to silently overwrite the other. A memd inbox sweep running between a file's open and close could read a partially-written note.
**Root cause:** Filename used `datetime.now().strftime("%Y%m%d-%H%M%S")` (second resolution) — two processes collide at the same second. File was written directly to the inbox path without atomicity.
**Prevention:** Use microsecond-resolution timestamp + PID in filename (`{YYYYMMDD-HHMMSSffffff}-{slug}-{pid}.md`). Publish via `os.replace()` from a temp file written *outside* the inbox directory — inbox sees a complete file or nothing. Any shared file-system path written by multiple shim instances (one per Claude session) must be treated as concurrent from the start.

### 2026-06-26 — Inbox multi-writer race: plugin hardened but memd weakened on shared path
**Symptom:** Plugin's `remember` tool hardened with µs-timestamp + pid + atomic write (temp file outside target dir + os.replace). Concurrent memd session found memd's own `write_inbox_note()` — which also writes to the SAME `~/.memory/inbox/` — does NOT have matching hardening. Both tools and other writers share one inbox; it is only as safe as its weakest writer.
**Root cause:** Plugin session checked memd's code in isolation and claimed identical hardening without verifying actual write behavior. memd's `write_inbox_note()` does not enforce the same atomic pattern (temp outside target + replace).
**Prevention:** Shared file-system resources (like `~/.memory/inbox/`) require ALL concurrent writers to enforce identical atomic-write discipline. Any tool or service writing to a shared inbox must: (1) write to a temp file outside the target directory, (2) publish via os.replace() or equivalent atomic rename, (3) use collision-proof names (µs-timestamp + pid minimum). Verify in next memd session and harden memd's writer to match plugin if not already done.

### 2026-06-26 — Inbox multi-writer concurrency: verification complete
**Follow-up to "Inbox multi-writer race" entry:** User analysis confirms functional equivalence on safety. Plugin: `os.replace(tmp, final)` with µs-timestamp+pid names (collision impossible). memd: `os.link()` with same naming scheme. Clobber path in plugin is unreachable in practice. No fsync on either writer (durability gap, out of scope). Both writers sufficiently hardened for shared `~/.memory/inbox/` use. No further action required.
