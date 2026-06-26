---
type: todo
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Open Tasks & Roadmap

## Phase 1: v1 Delivery — COMPLETE (2026-06-26)
Standalone plugin repo, Perceive/Act/Pulse end-to-end verified, MCP shim live, hardening finished, repo split, symlinked, MCP registered. Three commits pending push (user to push via SSH outside sandbox).

## Immediate (after push)
- [ ] **Push 3 commits to origin/main** — User pushing manually via SSH (unavailable in sandbox): `c5d03ac` (fsync durability), `c900f6e` + `e097c40` (memd distills).
- [ ] **Reload plugin in noctalia** — Shim is a persistent subprocess; new code (fsync, tools) only active after restart.

## Verify completed work
- [x] **Memd inbox hardening verified** — Plugin: `{µs-ts}-{slug}-{pid}` filename + `os.replace(tmp, final)` + fsync (file + directory). memd: same scheme + `os.link()`. Collision structurally impossible (PIDs unique across concurrent processes). Cross-session race closed by construction. fsync hardening added 2026-06-26 for durability against power-loss/panic.
- [ ] **Live-test context injection** — Reload plugin, `/cc <task>`, confirm `/mcp` in launched session lists `noctalia` server and `get_window` returns live data.
- [ ] **Live-test 4 act tools** — `focus_window`, `switch_workspace`, `move_to_workspace`, `set_wallpaper`: command-verified against `--help` but not yet executed against the real desktop.
- [ ] **Verify `remember` → memd chain** — Send a test note via `remember` tool in a `/cc` session; confirm memd sweep distills and clears inbox. Confirm memd handles new filename format and atomicity.

## Phase 2: Close the Loop — Remaining
- [ ] **Token/cost telemetry in pulse** — Model + token-burn in widget tooltip via MCP `onIpc` payload + tooltip wiring.
- [ ] **Pulse multi-session disambiguation** — Add session IDs to onIpc payload + aggregate state.
- [ ] **Presence orb (v1.1)** — Breathing/halo animation via `setNeedsFrameTick`/`onFrameTick`.
- [ ] **Auto-settle timer** — Bell→robot fade after idle delay (optional UX).

## Phase 3: Second Backend (deferred)
Local backend (ollama) + privacy-tier gating.

## Phase 4: Hardening & Polish (deferred)
Shim Python→Rust port; quick-ask read-only Q&A panel; publish to noctalia community.
