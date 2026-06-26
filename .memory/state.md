---
type: state
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# System State

## v1 Status (2026-06-26)
Live and verified end-to-end. Perceive + Act + Pulse architecture functional. Context injection in `/cc` implemented and verified. Shim expanded to 15 tools. **Phase 1 live-test verification complete this session:** MCP handshake + all perceive tools returning live data; all act tools (`focus_window`, `switch_workspace`, `notify`, `set_wallpaper` both branches) executed against real desktop; `remember`→memd chain fully closed (atomic write, distilled, inbox cleared). Plugin requires reload in noctalia to expose Phase 2 updates (token telemetry).

## What This Project Is
noctalia-claude-plugin — Claude Code companion plugin for Noctalia v5 desktop shell (niri / Wayland). Own repo, pushed to github.com/lowcache/noctalia-claude-plugin. Symlinked live at `~/.local/share/noctalia/plugins/claude`. MCP shim registered in `~/.nix-config/.mcp.json` (stdio: `python3 shim/noctalia-mcp.py`).

Thesis: shell is Claude's desktop **senses + actuators**, NOT a chat-UI reimplementation. Terminal remains home for heavy agentic work; shell adds ambient integration.

## Architecture — Three Nerves (IPC-verified, zero C++ fork required)
- **Perceive:** MCP shim queries system directly (`niri msg`, `playerctl`, `/sys`, `nmcli`). Noctalia IPC used only for noctalia-internal state.
- **Act:** `noctalia msg <target> <action>` — request/response, action path proven.
- **Pulse:** Claude hook → `noctalia msg plugin lowcache/claude:pulse all <event> [payload]` → bar widget `onIpc(event,payload)` → animates via `onFrameTick`.

## Pulse Widget
State machine: idle → turn_start → tool_start → needs_attention → turn_end.

**Icons & meaning:**
- idle: robot
- turn_start: brain (Claude thinking)
- tool_start: wrench (tool active)
- needs_attention: bell-ringing red (user action needed)
- turn_end: bell-ringing primary (persists; signals "awaiting your next message")

**Phase 2 — Token/cost telemetry (2026-06-26, implemented & verified):**
Tip now renders model + token burn: `model · fresh+cached-create in / out · cache-read`. Dispatcher (`hooks/pulse.py`) parses session transcript incrementally (O(delta)), computes cumulative usage, sends CSV payload to widget. Token accounting cross-checked via independent tether/Gemini parse (45129 in / 112432 out / 202412 cache-create / 4589306 cache-read — exact match). Formatting algorithm validated via Python port. Awaiting plugin reload to make live.

## MCP Shim (`shim/noctalia-mcp.py`)
Handshake verified. 15 tools total:
- **Perceive:** `get_window`, `get_workspace`, `get_media`, `get_shell_state`, `get_power`, `get_network`, `get_processes`
- **Actuate:** `notify`, `set_theme_mode`, `set_color_scheme`, `focus_window`, `switch_workspace`, `move_to_workspace`, `set_wallpaper`
- **Memory:** `remember` (write to global memd inbox)

Robustness: validated with adversarial input. **remember tool hardening:** µs-timestamp + pid filename scheme (collision-proof across concurrent shim instances); atomic publish via temp write + `os.replace()`; fsync before replace (file durability) and fsync on directory after replace (rename durability) to guard against power-loss/panic. Inbox safety verified equivalent with memd's `os.link` writer; collision structurally impossible by PID uniqueness, both handle concurrency safely. Hardened filename format (µs-ts-slug-pid) successfully parsed by memd distiller.

## Context Injection in `/cc` (2026-06-26)
cc.luau passes `--mcp-config` (inline JSON pointing at shim) + `--append-system-prompt` (role note listing tools) to every `task` and `continue` launch. Verified end-to-end headless.

## Session Hooks (`~/.claude/settings.json`)
All resilient to noctalia being offline. Updated to route through `hooks/pulse.py` dispatcher (Phase 2).

## Luau Dev Harness (new, 2026-06-26)
Test infrastructure under `nix/` and `tests/`:
- `nix/flake.nix` — provides luau 0.714 toolchain + test runner app
- `tests/prelude.luau` — stubs noctalia widget API for headless execution
- `tests/spec.luau` — spec-driven test cases (onIpc payloads, tooltip rendering, state transitions)
Allows offline validation of widget logic without full noctalia reload cycle.

## Repository & Integration
- **Repo:** ~/CodeRepo/noctalia-claude-plugin (git, own history)
- **Plugin symlink:** ~/.local/share/noctalia/plugins/claude
- **MCP registration:** ~/.nix-config/.mcp.json
- **Claude Code hooks:** ~/.claude/settings.json

## Current Working Tree (2026-06-26)
Phase 2 implementation staged, not yet committed:
- `M pulse.luau` — token telemetry tooltip rendering
- `M hooks/settings.snippet.json` — dispatcher routing
- `?? hooks/pulse.py` — token burn dispatcher
- `?? nix/flake.nix` — luau dev toolchain
- `?? tests/prelude.luau` — widget API stubs
- `?? tests/spec.luau` — test spec

**Awaiting:** (1) Commit (user to decide), (2) Plugin reload in noctalia, (3) Settings merge into `~/.claude/settings.json`, (4) Run a real `/cc` turn to verify tooltip populates.
