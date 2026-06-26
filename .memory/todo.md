---
type: todo
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Open Tasks & Roadmap

## Phase 1: v1 Delivery — COMPLETE (2026-06-26)
Standalone plugin repo, Perceive/Act/Pulse end-to-end verified, MCP shim live, hardening finished, repo split, symlinked, MCP registered.

## Immediate (next session)
- [ ] **BLOCKING: Verify memd inbox writer hardening** — concurrent memd session found memd's `write_inbox_note()` is weaker than plugin's `remember` hardening on the SAME shared `~/.memory/inbox/` directory. Inbox is a multi-writer resource; all writers must have identical atomic guarantees. Verify/fix in memd; unblock plugin push after memd is hardened to match.
- [ ] **Push 2 commits** — `git push origin main` (no force): `0f0a2b7` (remember fix) + `ce30ec7` (7 new tools). **Depends on memd verification above.**
- [ ] **Reload plugin in noctalia** — shim is a persistent subprocess; new code only active after restart.

## Verify completed work
- [ ] **Live-test context injection** — reload plugin, `/cc <task>`, confirm `/mcp` in launched session lists `noctalia` server and `get_window` returns live data.
- [ ] **Live-test 4 act tools** — `focus_window`, `switch_workspace`, `move_to_workspace`, `set_wallpaper`: command-verified against `--help` but not yet executed against the real desktop.
- [ ] **Verify `remember` → memd chain** — send a test note via `remember` tool in a `/cc` session; confirm memd sweep distills and clears. Confirm memd handles new filename format and atomicity.

## Phase 2: Close the Loop — Remaining

- [ ] **Token/cost telemetry in pulse** — model + token-burn in widget tooltip via MCP `onIpc` payload + tooltip wiring.
- [ ] **Pulse multi-session disambiguation** — add session IDs to onIpc payload + aggregate state.
- [ ] **Presence orb (v1.1)** — breathing/halo animation via `setNeedsFrameTick`/`onFrameTick`.
- [ ] **Auto-settle timer** — bell→robot fade after idle delay (optional UX).

## Phase 3: Second Backend (deferred)
Local backend (ollama) + privacy-tier gating.

## Phase 4: Hardening & Polish (deferred)
Shim Python→Rust port; quick-ask read-only Q&A panel; publish to noctalia community.
