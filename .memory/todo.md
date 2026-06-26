---
type: todo
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Open Tasks & Roadmap

## Phase 1: v1 Delivery — COMPLETE (2026-06-26)
Standalone plugin repo, Perceive/Act/Pulse end-to-end verified, MCP shim live, hardening finished, repo split, symlinked, MCP registered.

## AWAITING USER ACTION
- [ ] **Commit verified working-tree changes** — `pulse.luau` (turn_end bell icon), `cc.luau` (parse/accumulate), `shim/noctalia-mcp.py` (hardening). Verified + live-tested, not yet committed.

## Phase 2: Close the Loop (recommended next)
Perceive/Act/Pulse closure. Priority order:

### Early pull (high value, short scope)
- [ ] **Context injection in `/cc`** — spawn `claude` with `--mcp-config` + `--append-system-prompt` carrying live system senses + noctalia tool notes. Lets launched sessions query environment (window/workspace/dark mode) and invoke actions (notify, theme switch, window focus/move, workspace switch).
- [ ] **Token/cost telemetry in pulse** — show model + token-burn in widget tooltip via MCP `onIpc` payload + tooltip wiring. Addresses token-sensitivity.

### Core scope
- [ ] **Expand shim tools** — act: `set_wallpaper`, window focus/move, workspace switch (`niri msg`); senses: battery/power, wifi, running processes.
- [ ] **Presence orb (v1.1)** — breathing/halo animation via `setNeedsFrameTick`/`onFrameTick` (polish over current bar dot).
- [ ] **Auto-settle timer** — bell→robot fade after idle delay (optional UX).

## Phase 3: Second Backend (deferred)
Local backend (ollama) + privacy-tier gating (local unlocks high-tier senses: screen/clipboard/files).

## Phase 4: Hardening & Polish (deferred)
Shim Python→Rust port; quick-ask read-only Q&A panel; publish to noctalia community.
