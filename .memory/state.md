---
type: state
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# System State

## v1 Status (2026-06-26)
Live and verified end-to-end. Perceive + Act + Pulse architecture functional. Context injection in `/cc` implemented and verified. Shim expanded to 15 tools. Three commits pending push to GitHub: one fsync durability hardening, two memd distills. Plugin requires reload in noctalia to expose updated tools.

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

## MCP Shim (`shim/noctalia-mcp.py`)
Handshake verified. 15 tools total:
- **Perceive:** `get_window`, `get_workspace`, `get_media`, `get_shell_state`, `get_power`, `get_network`, `get_processes`
- **Actuate:** `notify`, `set_theme_mode`, `set_color_scheme`, `focus_window`, `switch_workspace`, `move_to_workspace`, `set_wallpaper`
- **Memory:** `remember` (write to global memd inbox)

Robustness: validated with adversarial input. **remember tool hardening:** µs-timestamp + pid filename scheme (collision-proof across concurrent shim instances); atomic publish via temp write + `os.replace()`; fsync before replace (file durability) and fsync on directory after replace (rename durability) to guard against power-loss/panic. Inbox safety verified equivalent with memd's `os.link` writer; collision structurally impossible by PID uniqueness, both handle concurrency safely.

## Context Injection in `/cc` (2026-06-26)
cc.luau passes `--mcp-config` (inline JSON pointing at shim) + `--append-system-prompt` (role note listing tools) to every `task` and `continue` launch. Verified end-to-end headless.

## Session Hooks (`~/.claude/settings.json`)
All resilient to noctalia being offline.

## Repository & Integration
- **Repo:** ~/CodeRepo/noctalia-claude-plugin (git, own history)
- **Plugin symlink:** ~/.local/share/noctalia/plugins/claude
- **MCP registration:** ~/.nix-config/.mcp.json
- **Claude Code hooks:** ~/.claude/settings.json

## Current Working Tree (2026-06-26)
Three commits pending push to origin/main:
- `c5d03ac` fix(shim): fsync remember note + inbox dir for crash durability
- `c900f6e` Update project memory (sweep distill)
- `e097c40` Update project memory (sweep distill)

**Status:** User pushing manually via SSH (unavailable in sandbox). After push, reload plugin in noctalia for new code to take effect.
