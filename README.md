# Claude Code Companion (Noctalia v5)

The shell-side **body** for Claude Code — senses, hands, and an attention pulse.
Not a chat client: the terminal does the agentic work (permissions, tools, MCP all
native); this plugin adds what Claude lacks — perception of your running env, the
ability to act on it, and a glanceable signal when it wants you.

## Status

v1.0.0 — built and live-tested end-to-end against noctalia 5.0.0 (flake input rev
`623210223c`). Shipped: the bar **pulse** widget with multi-session token
telemetry, the **presence orb** desktop widget, a sine-breath bar animation that
follows the active palette, the **answer panel** for `/cc ?` quick-asks, and an
agent-agnostic **pulse protocol** ([PROTOCOL.md](PROTOCOL.md)) with a generic
`pulse-emit` adapter. 54 offline widget specs pass under the nix test harness.

## The three nerves

| Nerve | Where | Path |
|---|---|---|
| **Perceive** | `shim/noctalia-mcp.py` | `niri msg -j` / `playerctl` / `noctalia msg status` |
| **Act** | `shim/` + `cc.luau` | `noctalia msg <action>` (reply on stdout); `notify-send` for toasts |
| **Pulse** | `pulse.luau` + `hooks/` | agent hooks → `noctalia msg plugin lowcache/claude:pulse all <event> [payload]` → `onIpc` → bar + orb react |

The pieces:

- `cc.luau` — the `/cc` launcher provider (terminal session launch + one-shot ask)
  and the single backend chokepoint (`invoke`/`parse`, normalized event vocabulary).
- `pulse.luau` — the bar widget and **sole aggregator**: tracks every session,
  renders the most urgent state, breathes the accent color, and mirrors its rollup
  to `noctalia.state` (`cc.pulse`) for subscribers.
- `orb.luau` — the desktop presence orb: subscribes to `cc.pulse` and breathes the
  same state via per-frame ticks (sine-driven opacity + glyph scale, tempo keyed
  to urgency). Pure view, no hooks of its own.
- `answer.luau` — the `[[panel]]` that carries `/cc ?` answers in full, wrapped and
  scrollable (a toast clips long bodies).
- `shim/noctalia-mcp.py` — stdio MCP shim giving Claude desktop senses and hands.
- `hooks/pulse.py` — the Claude Code hook adapter (transcript-derived token
  telemetry); `hooks/pulse-emit` — the generic POSIX-sh adapter for anything else.

## REQUIRED: the `pulse` widget must be placed on a bar

The `pulse` bar widget is the **sole aggregator** of the whole system: it receives
the hook IPC events and publishes the `cc.pulse` state everything else subscribes
to. Noctalia bar widgets only run while placed on a bar, and noctalia 5.0.0 has no
headless service entry kind — so **removing `pulse` from your bar silently
disables the entire plugin**. Hooks keep firing, but nobody listens: the state
never updates, and the orb and answer panel freeze at their last state.

Failure symptom: the bar icon is gone (or stuck), the orb breathes forever at one
state no matter what Claude does, and manual `noctalia msg plugin
lowcache/claude:pulse …` pokes change nothing. Fix: re-add the `pulse` widget to a
bar in noctalia's settings and keep it there.

## Install

1. Clone and symlink into the plugins dir:
   `ln -s "$PWD" ~/.local/share/noctalia/plugins/claude`
2. Enable the plugin: `noctalia msg plugins enable lowcache/claude`.
3. **Place the `pulse` widget on a bar** (Settings → Bar) — see the warning above;
   this step is not optional. `/cc` appears in the launcher.
4. Optionally add the `orb` desktop widget for the ambient desktop presence.
5. Merge `hooks/settings.snippet.json` into `~/.claude/settings.json` so Claude
   Code's lifecycle hooks drive the pulse.
6. Point Claude at `shim/noctalia-mcp.py` via `--mcp-config` to expose the
   senses/hands tools. (`/cc`-launched sessions wire the shim in automatically.)

Smoke test (plugin enabled + widget placed):
`noctalia msg plugin lowcache/claude:pulse all needs_attention` → the bar icon
turns into a red bell; `... all idle` → back to the robot.

## Usage

- `/cc <task>` — launch a real Claude Code TUI session in the terminal, with the
  noctalia MCP shim and a desktop-awareness note wired in.
- `/cc` — resume the last session (`claude --continue`), same wiring.
- `/cc ? <question>` — one-shot read-only ask. The answer arrives as a toast
  preview; the complete text is published to the answer panel. Open the panel by
  clicking the bar pulse, via the "Show last answer" row under `/cc`, or with
  `noctalia msg panel-open lowcache/claude:answer`. While the panel is open it
  refreshes live and the toast is suppressed (one surface per answer). Dismiss
  with a click outside or Esc.

The bar tooltip shows per-session state and token burn (input / output / cache
reads); with several sessions it lists each one plus a Σ total, and the icon shows
the most urgent state across all of them.

## Driving the pulse from other agents

The pulse wire format is agent-agnostic — the widget consumes events, not Claude
specifics. Any agent, CI job, or script that can run a shell command on its
lifecycle can light up the same bar: see [PROTOCOL.md](PROTOCOL.md) for the
eight-event vocabulary, the CSV payload, session semantics, and the fail-open
adapter contract, and use `hooks/pulse-emit` (plain POSIX sh, no dependencies
beyond `noctalia` on PATH) as the reference emitter:

```sh
hooks/pulse-emit turn_start mysess
hooks/pulse-emit turn_end mysess gpt-5 12000 800
hooks/pulse-emit session_end mysess
```

## Known constraints

- Noctalia plugin panels render at Layer::Top, so overlay windows (notifications,
  quake terminals, polkit prompts) can cover the answer panel — the answer still
  lands; dismiss the overlay to see it. Upstream ask filed for panel layer control.
- Bar widgets don't fire `state.watch` callbacks in noctalia 5.0.0 (the plugin
  polls instead) and ignore 8-digit hex alpha (brightness is done via RGB scaling).
- Builtin and wallpaper-generated palettes have no on-disk JSON, so those sources
  fall back to fixed accent colors; custom and community palettes are followed
  live (~8 s re-check).
- The MCP shim is a Python prototype; a compiled port is the intended release form.
- The shim's memory tool drops durable notes into `~/.memory/inbox` for the memd
  curator to distill; without memd installed it is inert — files are written,
  nothing reads them.

## Development

`nix/` carries a self-contained luau toolchain for testing the widget logic
(`pulse.luau`, `orb.luau`, `answer.luau`) offline — no noctalia reload needed to
catch a regression in the state machine, the token-burn tooltip formatting, the
orb's breath math, or the answer panel's render guard.

```sh
nix run ./nix#test        # run every widget suite (from the repo root)
nix run ./nix#pulse       # bar dot only        nix run ./nix#orb     # presence orb only
nix develop ./nix         # shell with luau     nix run ./nix#answer  # answer panel only
```

Each runner concatenates a stub prelude (the `barWidget`/`desktopWidget`/`ui`/
`noctalia` API), the real widget source, and its spec into one chunk and runs it
under `luau`, asserting on what the stubs record. Specs validate the shipping
source, not a copy. 54 specs total (38 pulse + orb, 16 answer panel).

## License

MIT — see [LICENSE](LICENSE).
