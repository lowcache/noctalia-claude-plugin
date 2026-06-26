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
