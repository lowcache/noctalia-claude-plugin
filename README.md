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
`[CEILING]:` markers are genuine deferrals (ollama backend, stream-json schema
drift), not unknowns. **Next: live-install + a bar dispatch test.**

## v1 shape (the three nerves)

| Nerve | Where | Path |
|---|---|---|
| **Perceive** | `shim/noctalia-mcp.py` | `niri msg -j` / `playerctl` / `noctalia msg status` |
| **Act** | `shim/` + `cc.luau` | `noctalia msg <action>` (reply on stdout); `notify-send` for toasts |
| **Pulse** | `pulse.luau` + `hooks/` | Claude hooks → `noctalia msg plugin lowcache/claude:pulse all <event>` → `onIpc` → bar reacts |

The pulse wire format is agent-agnostic — see **[PROTOCOL.md](PROTOCOL.md)** for
the event vocabulary, payload CSV, session semantics, and the fail-open adapter
contract. `hooks/pulse.py` is the Claude Code adapter (telemetry-enriched);
`hooks/pulse-emit` is a generic POSIX-sh emitter for any other agent or script.

- `cc.luau` — `/cc` launcher (terminal launch + one-shot ask) **and** the single
  backend chokepoint (`invoke`/`parse`, normalized event vocabulary). claude-only,
  seam open for ollama/router later.
- `pulse.luau` — bar widget; discrete state-language (idle/thinking/tool/needs-you/
  done). Mirrors its session rollup to `noctalia.state` (`cc.pulse`) for the orb.
- `orb.luau` — the desktop "presence orb": a `[[desktop_widget]]` that subscribes to
  `cc.pulse` and *breathes* the same state via `setNeedsFrameTick`/`onFrameTick`
  (sine-driven opacity + glyph scale, tempo keyed to urgency). Pure view, no hooks.
- `answer.luau` — the `[[panel]]` that carries `/cc ?` answers in full: a toast
  clips long bodies with no scroll, so `cc.luau` publishes the complete text to
  `noctalia.state` (`cc.answer`) and the panel renders it wrapped + scrollable.
  Open it by clicking the bar pulse, from the "Show last answer" row under `/cc`,
  or `noctalia msg panel-toggle lowcache/claude:answer`. Pure view, like the orb.
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
- **Live-install + bar/orb dispatch test** (the smoke test above, plus placing the
  orb desktop widget) — the only unverified link; everything else is checked against
  source / a local handshake.
- `--mcp-config` entry so Claude actually calls the shim mid-session; then expand
  the senses/hands tool set.
- Privacy-tier gate keyed to backend locality (when a local backend lands).
- Re-verify `parse()` field names if a claude version changes the stream-json shape.

## Development

`nix/` carries a self-contained luau toolchain for testing the widget logic
(`pulse.luau`, `orb.luau`, `answer.luau`) offline — no noctalia reload needed to
catch a regression in the state machine, the token-burn tooltip formatting, the
orb's breath math, or the answer panel's render guard.

```sh
nix run ./nix#test        # run every widget suite (from the repo root)
nix run ./nix#pulse       # bar dot only       nix run ./nix#orb     # presence orb only
nix develop ./nix         # shell with luau     nix run ./nix#answer  # answer panel only
```

Each runner concatenates a stub prelude (the `barWidget`/`desktopWidget`/`ui`/
`noctalia` API), the real widget source, and its spec into one chunk and runs it
under `luau`, asserting on what the stubs record. The pulse suite drives `onIpc` +
`barWidget`; the orb suite drives the `cc.pulse` watch callback + `onFrameTick` and
asserts on the rendered `ui` tree (disc color/opacity, glyph, breath bounds). Specs
validate the shipping source, not a copy — but logic only; the live noctalia
integration (IPC dispatch, real bar/desktop rendering) still needs an install + reload.

Design rationale captured in nix-config `.memory` (decision:
claude-code-plugin-v1-design).
