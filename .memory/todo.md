---
type: todo
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Open Tasks & Roadmap

## Phase 1: v1 Delivery — COMPLETE (2026-06-26)
Standalone plugin repo, Perceive/Act/Pulse end-to-end verified, MCP shim live, hardening finished, repo split, symlinked, MCP registered. Three commits pushed to origin/main (user pushed via SSH). Live-test verification complete this session.

### Completed this session (2026-06-26)
- [x] **Push 3 commits to origin/main** — User pushed outside sandbox; `main...origin/main` shows no divergence.
- [x] **Verify MCP handshake + tools/list** — shim returns all 15 tools with valid inputSchema.
- [x] **Verify perceive tools** — `get_window`, `get_workspace`, `get_power`, `get_shell_state` all return live data.
- [x] **Verify `remember`→memd chain** — note written atomically (µs-ts-slug-pid format), distilled, inbox cleared, no pollution to global memory.
- [x] **Verify act tools** — `focus_window` (id 96, no-op safe), `switch_workspace` (ref 2, no-op safe), `notify` (fired), `set_wallpaper` random + restore branches both executed against real desktop.

## Phase 2: Token/Cost Telemetry — COMPLETE (2026-06-26)

### Completed this session
- [x] **Implement token-burn dispatcher** — `hooks/pulse.py` parses session transcript JSONL incrementally, computes cumulative model + 4-part token usage (input, output, cache-create, cache-read), sends CSV payload via `noctalia msg plugin` IPC.
- [x] **Implement tooltip rendering** — `pulse.luau` `onIpc(event, payload)` now renders `model · fresh+cc in / out · cr cached` tooltip. Uses full-rate input (fresh + cache-create) to avoid understating burn when most input is cached context.
- [x] **Token accounting verification** — Independent tether/Gemini parse of identical transcript snapshot matched dispatcher's totals exactly (45129 / 112432 / 202412 / 4589306).
- [x] **Luau algorithm validation** — Tooltip formatting (kfmt, split, compose) validated via faithful Python port. Edge cases correct (empty → clean tip; no cache → segment omitted; missing fields → zeros).
- [x] **Route hooks through dispatcher** — Updated `hooks/settings.snippet.json` to invoke `python3 .../pulse.py <event>` for all 6 lifecycle hooks.

### Immediate (after user action, not blocked)
- [ ] **Merge settings into ~/.claude/settings.json** — `hooks/settings.snippet.json` contains new paths to `python3 .../pulse.py` for all 6 hooks. User to merge into live settings.
- [ ] **Reload plugin in noctalia** — Shim is a persistent subprocess; new code (pulse.py dispatcher + luau) only active after restart.
- [ ] **Run a real `/cc` turn** — Verify that token telemetry tooltip populates in the widget. Luau runtime path unvalidated until reload.

## Luau Dev Harness (scaffolded, 2026-06-26)
- [x] **Create test infrastructure** — `nix/flake.nix` (toolchain + test runner), `tests/prelude.luau` (widget API stubs), `tests/spec.luau` (test cases).
- [ ] **Lock flake and run specs** — Awaiting commit so staged files are visible to `nix flake lock`. Specs validate onIpc payloads, tooltip formatting, state machine transitions.

## Phase 2 Continued — Pulse Multi-Session Disambiguation
- [ ] **Add per-session aggregation** — `session` field already on wire in CSV payload; widget currently shows single-session telemetry. Extend to keep per-session table, aggregate across active sessions (token burn, model, state).

## Phase 3: Second Backend (deferred)
Local backend (ollama) + privacy-tier gating.

## Phase 4: Hardening & Polish (deferred)
Shim Python→Rust port; quick-ask read-only Q&A panel; publish to noctalia community.
