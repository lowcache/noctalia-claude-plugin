# Claude Code Companion (Noctalia v5)

The shell-side **body** for Claude Code — senses, hands, and an attention pulse.
Not a chat client: the terminal does the agentic work (permissions, tools, MCP all
native); this plugin adds what Claude lacks — perception of your running env, the
ability to act on it, and a glanceable signal when it wants you.

## Status: implemented against the verified 5.0.0 API — not yet live-installed

The upstream prereqs (the `[[panel]]` kind, `ui` controls, plugin IPC dispatch, the
`barWidget`/`onIpc` surface) shipped in the 5.0.0 build running here (flake input
rev `623210223c`). Every entry below was rewritten against the **verified** API
read from that source — the earlier `[CEILING]:` guesses (`widget.*`, one-arg
`onIpc`, `noctalia msg pulse`, `theme-set`, Lua `%q` quoting) are corrected. The
MCP shim's JSON-RPC loop is implemented and passes a local handshake. Remaining
`[CEILING]:` markers are genuine deferrals (the orb variant, ollama backend,
stream-json schema drift), not unknowns. **Next: live-install + a bar dispatch test.**

## v1 shape (the three nerves)

| Nerve | Where | Path |
|---|---|---|
| **Perceive** | `shim/noctalia-mcp.py` | `niri msg -j` / `playerctl` / `noctalia msg status` |
| **Act** | `shim/` + `cc.luau` | `noctalia msg <action>` (reply on stdout); `notify-send` for toasts |
| **Pulse** | `pulse.luau` + `hooks/` | Claude hooks → `noctalia msg plugin lowcache/claude:pulse all <event>` → `onIpc` → bar reacts |

- `cc.luau` — `/cc` launcher (terminal launch + one-shot ask) **and** the single
  backend chokepoint (`invoke`/`parse`, normalized event vocabulary). claude-only,
  seam open for ollama/router later.
- `pulse.luau` — bar widget; discrete state-language (idle/thinking/tool/needs-you/
  done). Smooth breathing/halo = the desktop "presence orb" variant, **v1.1**.
- `shim/noctalia-mcp.py` — stdio MCP shim (prototype; port to Rust for release).
- `hooks/settings.snippet.json` — merge into `~/.claude/settings.json`.
- `config.example.toml` — the backend seam, documented (not yet read).

## Wiring

1. Symlink into the plugins dir: `ln -s "$PWD" ~/.local/share/noctalia/plugins/claude`
2. `noctalia msg plugins enable lowcache/claude`, then add the `pulse` bar widget
   to a bar (Settings → Bar) and reload. `/cc` appears in the launcher.
3. Merge `hooks/settings.snippet.json` into `~/.claude/settings.json` for the reflex.
4. Point Claude at the shim via `--mcp-config` to expose the senses/hands tools.

Smoke test (plugin enabled + widget placed):
`noctalia msg plugin lowcache/claude:pulse all needs_attention` → bar dot turns to
a red bell; `... all idle` → back to the robot. (Before install the same command
returns `error: no plugin entry matched`, which confirms the dispatch path.)

## Open items
- **Live-install + bar dispatch test** (the smoke test above) — the only unverified
  link; everything else is checked against source / a local handshake.
- The desktop "presence orb" — smooth breathing via `setNeedsFrameTick`/`onFrameTick`
  (v1.1; the bar dot is v1).
- `--mcp-config` entry so Claude actually calls the shim mid-session; then expand
  the senses/hands tool set.
- Privacy-tier gate keyed to backend locality (when a local backend lands).
- Re-verify `parse()` field names if a claude version changes the stream-json shape.

Design rationale captured in nix-config `.memory` (decision:
claude-code-plugin-v1-design).
