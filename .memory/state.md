---
type: state
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# System State

## v1 Status (2026-06-26)
Live and verified end-to-end. Perceive + Act + Pulse architecture functional. Context injection in `/cc` implemented and verified. Shim expanded to 15 tools. Git history cleaned into 7 atomic commits. Two commits ready to push to GitHub; plugin requires reload in noctalia to expose new tools.

**CRITICAL FINDING (concurrent session):** Plugin's `remember` tool uses µs-timestamp + pid + atomic write (os.replace). Concurrent memd session discovered memd's own `write_inbox_note()` — which writes to the SAME shared `~/.memory/inbox/` — is weaker/non-atomic. Shared inbox path is only as safe as its weakest writer. Plugin hardening is incomplete until memd is hardened to match.

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

Robustness: validated with adversarial input. `remember` hardened with µs-timestamp + pid + atomic write (os.replace temp → inbox).

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
Clean. Commits ready to push to origin/main:
- `0f0a2b7` fix(shim): make remember concurrency-safe (unique names + atomic write)
- `ce30ec7` feat(shim): add desktop senses (power/network/processes) and hands (focus/workspace/wallpaper)

**Action:** `git push origin main` (no force needed; extends history).
