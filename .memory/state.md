---
type: state
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# System State

## v1 Status (2026-06-26)
Live and verified end-to-end. Perceive + Act + Pulse architecture functional. Hardening complete: 2 HIGH crash vectors in MCP shim fixed, 1 MED schema issue fixed, 3 cc.luau enhancements. Server survives adversarial input (garbage/non-dict JSON/non-string args); returns proper error objects.

## What This Project Is
noctalia-claude-plugin — Claude Code companion plugin for Noctalia v5 desktop shell (niri / Wayland). Own repo, pushed to github.com/lowcache/noctalia-claude-plugin. Symlinked live at `~/.local/share/noctalia/plugins/claude`. MCP shim registered in `~/.nix-config/.mcp.json` (stdio: `python3 shim/noctalia-mcp.py`).

Thesis: shell is Claude's desktop **senses + actuators**, NOT a chat-UI reimplementation. Terminal remains home for heavy agentic work; shell adds ambient integration.

## Architecture — Three Nerves (IPC-verified, zero C++ fork required)
- **Perceive:** MCP shim queries system directly (`niri msg`, `playerctl`, `/sys`). Noctalia IPC used only for noctalia-internal state.
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
Handshake verified. Available tools:
- **Perceive:** `get_window`, `get_workspace`, `get_media`, `get_shell_state`
- **Actuate:** `notify`, `set_theme_mode`, `set_color_scheme`
- **Memory:** `remember` (write to global memd inbox)

Robustness: validated with adversarial input (garbage JSON, non-dict, non-string args, unknown tools); shim returns proper error objects in all cases. Lesson: shim is untrusted-input boundary (stdin JSON-RPC) — validate types/shape and return error objects, never assume dict/str.

**Live test results:**
- `get_window`: focused kitty session
- `get_workspace`: eDP-1 1920×1200
- `get_shell_state`: valid JSON
- `notify`: desktop toast fired
- `remember`: wrote to `~/.memory/inbox/`

## Session Hooks (`~/.claude/settings.json`)
All resilient to noctalia being offline:
- SessionStart → idle
- UserPromptSubmit → turn_start
- PreToolUse(*) → tool_start
- PostToolUse → turn_start
- Notification → needs_attention
- Stop → turn_end

## Repository & Integration
- **Repo:** ~/CodeRepo/noctalia-claude-plugin (git, own history)
- **Plugin symlink:** ~/.local/share/noctalia/plugins/claude
- **MCP registration:** ~/.nix-config/.mcp.json
- **Claude Code hooks:** ~/.claude/settings.json
- **Settings backup:** ~/.local/state/noctalia/settings.toml.bak.20260625-092856.preplugin

## Files of Record
- `cc.luau`: launcher / stream parser
- `pulse.luau`: bar widget
- `shim/noctalia-mcp.py`: MCP server

## Current Working Tree (2026-06-26)
Uncommitted verified changes:
- `pulse.luau`: turn_end icon bell
- `cc.luau`: parse/accumulate enhancements
- `shim/noctalia-mcp.py`: hardening fixes
