---
routed: noctalia-claude-plugin
topic: cc-path-fix
date: 2026-06-26
source: claude/session
---

BUGFIX (committed bfb81fc): /cc-launched claude sessions hit "command not found" for the memd + agent-scaffold SessionStart hooks. Root cause: noctalia launches via /bin/sh -c with the GRAPHICAL-session PATH, which lacks ~/.local/bin (where memd + agent-scaffold live; confirmed via `command -v`). The GUI PATH has /etc/profiles/per-user/lowcache/bin + /run/current-system/sw/bin (so claude/python3/noctalia + the pulse hooks resolve) but NOT ~/.local/bin, which the user's shell profile adds for terminals only.

FIX: cc.luau gains `local PATH_PREFIX = 'PATH="$HOME/.local/bin:$PATH" '` prepended to all three launch strings (task, continue, quick-ask backend_command). $HOME/$PATH expand in the sh -c context. Verified under luau: all three carry the prefix with --mcp-config/--append-system-prompt/--continue intact.

REQUIRES: another plugin reload (disable/enable lowcache/claude) for cc.luau to reload, then new /cc launches are clean.

SYSTEMIC ALTERNATIVE (not done; user's ~/.nix-config, out of this repo): add ~/.local/bin to the graphical-session PATH (home-manager home.sessionPath / session vars) so ALL GUI-launched programs match the terminal — would make the plugin-side prefix redundant but is the proper root fix. Plugin-side fix kept regardless as defensive (a plugin shouldn't assume GUI PATH == terminal PATH).

NOTED (separate, not fixed — out of scope): cc.luau's SYSTEM_NOTE (the --append-system-prompt role note) still lists only the original tool set (PERCEIVE get_window/get_workspace/get_media/get_shell_state; ACT notify/set_theme_mode/set_color_scheme; MEMORY remember). The shim now has 15 tools incl. get_power/get_network/get_processes + focus_window/switch_workspace/move_to_workspace/set_wallpaper. The role note is stale and undersells the hands/senses to launched sessions — worth refreshing.
