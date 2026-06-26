---
type: state
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# System State

## v1 Status (2026-06-26)
Live and verified end-to-end. Perceive + Act + Pulse architecture functional. Hardening complete: 2 HIGH crash vectors in MCP shim fixed, 1 MED schema issue fixed, 3 cc.luau enhancements. Server survives adversarial input (garbage/non-dict JSON/non-string args); returns proper error objects.

## Architecture
Three-nerve IPC-verified design:
- **Perceive:** MCP shim queries system (`niri msg`, `playerctl`, `/sys`)
- **Act:** `noctalia msg <target> <action>` (request/response)
- **Pulse:** Claude hooks → `noctalia msg plugin lowcache/claude:pulse all <event>` → widget animates

## Pulse Widget
State machine: idle → turn_start → tool_start → needs_attention → turn_end. Visual: bell-ringing glyph in niri top bar.

## MCP Shim (`shim/noctalia-mcp.py`)
Handshake verified. Available tools: `get_window`, `get_workspace`, `get_media`, `get_shell_state` (perception); `notify`, `set_theme_mode`, `set_color_scheme` (actuation); `remember` (write to global memd inbox).

## Repository & Integration
- **Repo:** ~/CodeRepo/noctalia-claude-plugin (git, own history, pushed to github.com/lowcache/noctalia-claude-plugin)
- **Plugin symlink:** ~/.local/share/noctalia/plugins/claude
- **MCP registration:** ~/.nix-config/.mcp.json (active)
- **Claude Code hooks:** ~/.claude/settings.json (session-start/end, pre-compact)
