---
type: state
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# System State

## v1 Status (2026-06-26)
Live and verified end-to-end. Perceive + Act + Pulse architecture functional. Context injection in `/cc` implemented and verified. Shim expanded to 15 tools. Git history cleaned into 7 atomic commits. Two commits not yet pushed to GitHub; plugin requires reload in noctalia to expose new tools.

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

Robustness: validated with adversarial input (garbage JSON, non-dict, non-string args, unknown tool); shim returns proper error objects in all cases.

`remember` concurrency-hardened (2026-06-26): filenames are `{µs-ts}-{slug}-{pid}.md` (collision-proof across concurrent sessions, each with its own shim subprocess); writes atomically via `os.replace()` from a temp file outside the inbox (memd sweep sees a complete file or nothing). Previous second-resolution names would collide silently.

**Act tools — command-verified, not yet executed against live desktop:**
- `focus_window`: `niri msg action focus-window --id <ID>`
- `switch_workspace`: `niri msg action focus-workspace <REFERENCE>` (index or name)
- `move_to_workspace`: `niri msg action move-column-to-workspace <REFERENCE>`
- `set_wallpaper`: `swww img <path> --transition-type grow`

**Live test results:**
- Original tools: `get_window` (kitty), `get_workspace` (eDP-1 1920×1200), `get_shell_state`, `notify` (toast fired), `remember` (wrote to inbox)
- New senses: `get_power` (BAT1: 100%/Full), `get_network` (connected + active SSID/signal), `get_processes` (top by CPU)

## Context Injection in `/cc` (2026-06-26)
cc.luau passes `--mcp-config` (inline JSON pointing at shim) + `--append-system-prompt` (role note listing tools) to every `task` and `continue` launch. Shim path uses bare `$HOME` (shell-expanded, not committed literally). A `dq()` helper quotes the fixed JSON; user task strings still go through `shq()`. Verified end-to-end headless: `claude --mcp-config` spawned shim, called `get_window`, returned live `niri msg` data. GUI live-test (reload plugin + `/cc <task>` + `/mcp` in launched session) pending after next noctalia reload.

## Pulse / Concurrency Note
Pulse widget shows last-event-wins from **any** concurrent Claude session — cosmetic ambiguity, not a crash. Multiple sessions each spawn their own independent shim (stateless); `remember` is now safe across sessions. Act tools operate on the one real desktop (last-write-wins, inherent to shared desktop).

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
- `cc.luau`: launcher / stream parser (context injection wired)
- `pulse.luau`: bar widget
- `shim/noctalia-mcp.py`: MCP server (15 tools, concurrency-hardened)
- `.gitignore`: excludes `__pycache__/` and `*.pyc`

## Current Working Tree (2026-06-26)
Clean. Commits not yet pushed to origin/main:
- `0f0a2b7` fix(shim): make remember concurrency-safe (unique names + atomic write)
- `ce30ec7` feat(shim): add desktop senses (power/network/processes) and hands (focus/workspace/wallpaper)

Push: `git push origin main` (no force needed; extends history).
