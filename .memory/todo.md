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
- [ ] **Push 2 commits** — `git push origin main` (no force): `0f0a2b7` (remember fix) + `ce30ec7` (7 new tools).
- [ ] **Reload plugin in noctalia** — shim is a persistent subprocess; new code (15 tools, atomic remember) only active after restart.

## Verify completed work
- [ ] **Live-test context injection** — reload plugin, `/cc <task>`, confirm `/mcp` in launched session lists `noctalia` server and `get_window` returns live data.
- [ ] **Live-test 4 act tools** — `focus_window`, `switch_workspace`, `move_to_workspace`, `set_wallpaper`: command-verified against `--help` but not yet executed against the real desktop.
- [ ] **Verify `remember` → memd chain** — send a test note via `remember` tool in a `/cc` session; confirm memd sweep distills and clears. Confirm memd inbox scanner handles new filename format (`{µs-ts}-{slug}-{pid}.md`) and ignores `.remember-*.tmp` dotfiles.

## Phase 2: Close the Loop — Remaining

- [ ] **Token/cost telemetry in pulse** — model + token-burn in widget tooltip via MCP `onIpc` payload + tooltip wiring. Addresses token-sensitivity.
- [ ] **Pulse multi-session disambiguation** — pulse currently shows last-event-wins from any session; add session IDs to onIpc payload + aggregate state. Pairs with token telemetry.
- [ ] **Presence orb (v1.1)** — breathing/halo animation via `setNeedsFrameTick`/`onFrameTick` (polish over current bar dot).
- [ ] **Auto-settle timer** — bell→robot fade after idle delay (optional UX).

## Phase 3: Second Backend (deferred)
Local backend (ollama) + privacy-tier gating (local unlocks high-tier senses: screen/clipboard/files).

## Phase 4: Hardening & Polish (deferred)
Shim Python→Rust port; quick-ask read-only Q&A panel; publish to noctalia community.
