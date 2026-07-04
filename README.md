# Claude Code Companion · Noctalia v5

![version](https://img.shields.io/badge/version-1.0.0-blue) ![license](https://img.shields.io/badge/license-MIT-informational) ![noctalia](https://img.shields.io/badge/noctalia-5.0.0-blueviolet) ![specs](https://img.shields.io/badge/specs-54%20passing-brightgreen)

What Claude Code lacks as a terminal agent is any awareness of your desktop — it can't see your windows, can't send a notification, and gives no ambient signal when it's waiting on you. This plugin fixes that by wiring noctalia into Claude's lifecycle: a bar pulse that tracks every active session, a presence orb on the desktop, and a one-shot ask panel that pops answers inline. The terminal still does all the agentic work (permissions, tools, MCP all native) — this just gives it a body.

Built and live-tested against noctalia 5.0.0 (flake input `623210223c`). Ships the `pulse` bar widget with multi-session token telemetry, the `orb` desktop widget with sine-breath animation, the `answer` panel for `/cc ?` quick-asks, and an agent-agnostic pulse protocol ([PROTOCOL.md](PROTOCOL.md)) with a generic `pulse-emit` adapter.

---

## How it fits together

| | Component | Role |
|---|---|---|
| **Perceive** | `shim/noctalia-mcp.py` | Reads your running env — `niri msg -j`, `playerctl`, `noctalia msg status` — and exposes it to Claude via MCP. Wired in automatically on `/cc` launch. |
| **Act** | `cc.luau` | The `/cc` launcher provider and sole backend chokepoint. Drives `notify-send` toasts and `noctalia msg` panel actions via a normalized event vocabulary. |
| **Pulse** | `pulse.luau` | Receives hook events via IPC, tracks every session, renders the most urgent state, breathes the accent color, and mirrors its rollup to `noctalia.state` (`cc.pulse`). |
| **Orb** | `orb.luau` | Pure view. Subscribes to `cc.pulse` and breathes the same state per-frame (sine-driven opacity + glyph scale, tempo keyed to urgency). No hooks of its own. |
| **Answer** | `answer.luau` | The `[[panel]]` that carries `/cc ?` answers in full — wrapped and scrollable where a toast would clip. |

---

## Install

```sh
# clone and symlink into the plugins dir
ln -s "$PWD" ~/.local/share/noctalia/plugins/claude

# enable the plugin
noctalia msg plugins enable lowcache/claude
```

1. **Add `pulse` to a bar** (Settings → Bar) — see the warning below; this is not optional.
2. Optionally add `orb` as a desktop widget for the ambient presence.
3. Merge `hooks/settings.snippet.json` into `~/.claude/settings.json` so Claude Code's lifecycle hooks drive the pulse.
4. Point Claude at `shim/noctalia-mcp.py` via `--mcp-config` to expose desktop senses and hands. (`/cc`-launched sessions do this automatically.)

Smoke test once you're set up:

```sh
noctalia msg plugin lowcache/claude:pulse all needs_attention   # bar icon → red bell
noctalia msg plugin lowcache/claude:pulse all idle              # back to robot
```

> [!WARNING]
> **The `pulse` widget must stay on a bar.** It's the sole aggregator for the whole system — it receives hook IPC events and publishes `cc.pulse` state. Noctalia bar widgets only run while placed on a bar, so if you remove it, the plugin goes silent. Hooks keep firing, nobody listens, state freezes.
>
> Symptom: bar icon stuck, orb breathes the same state forever, manual IPC pokes do nothing. Fix: put `pulse` back on a bar in noctalia's settings.

---

## Usage

| Command | What it does |
|---|---|
| `/cc <task>` | Launch a Claude Code TUI session in the terminal, noctalia MCP shim wired in. |
| `/cc` | Resume the last session (`claude --continue`), same wiring. |
| `/cc ? <question>` | One-shot read-only ask. Answer arrives as a toast and is published to the answer panel. |

The bar tooltip shows per-session state and token burn (input / output / cache reads). With several sessions running it lists each one plus a Σ total, and the icon reflects the most urgent state across all of them.

For the answer panel: open it via the bar pulse, the "Show last answer" row under `/cc`, or `noctalia msg panel-open lowcache/claude:answer`. While open it refreshes live and the toast is suppressed — one surface per answer. Dismiss with a click outside or Esc.

---

## Driving the pulse from other agents

The pulse wire format is agent-agnostic — the widget consumes events and doesn't care what produced them. Any agent, CI job, or script that can run a shell command on its lifecycle can light up the same bar. See [PROTOCOL.md](PROTOCOL.md) for the eight-event vocabulary, CSV payload, session semantics, and adapter contract. `hooks/pulse-emit` is the reference emitter — plain POSIX sh, no dependencies beyond `noctalia` on PATH:

```sh
hooks/pulse-emit turn_start mysess
hooks/pulse-emit turn_end mysess gpt-5 12000 800
hooks/pulse-emit session_end mysess
```

---

## Known constraints

- Plugin panels render at `Layer::Top`, so overlay windows (notifications, quake terminals, polkit prompts) can cover the answer panel. The answer still lands — dismiss the overlay to see it. Upstream ask filed for panel layer control.
- Bar widgets don't fire `state.watch` callbacks in noctalia 5.0.0, so the plugin polls instead. 8-digit hex alpha is ignored; brightness is done via RGB scaling.
- Builtin and wallpaper-generated palettes have no on-disk JSON, so those sources fall back to fixed accent colors. Custom and community palettes are followed live (~8 s re-check).
- The MCP shim is a Python prototype; compiled is the intended eventual form.
- The shim's memory tool drops notes into `~/.memory/inbox` for the memd curator. Without memd installed it's inert — files are written, nothing reads them. It implements memd's Inbox Protocol v1.0 (`INBOX-PROTOCOL.md` in the memd repo).

---

## Development

`nix/` carries a self-contained luau toolchain for testing widget logic offline — no noctalia reload needed to catch a regression in the state machine, token-burn tooltip formatting, orb breath math, or answer panel render guard.

```sh
nix run ./nix#test      # every widget suite
nix run ./nix#pulse     # bar widget only
nix run ./nix#orb       # presence orb only
nix run ./nix#answer    # answer panel only
nix develop ./nix       # shell with luau
```

Each runner concatenates a stub prelude (the `barWidget`/`desktopWidget`/`ui`/`noctalia` API surface), the real widget source, and its spec into one chunk and runs it under `luau`, asserting on what the stubs record. Specs validate the shipping source, not a copy. 54 specs total (38 pulse + orb, 16 answer panel).

---

## License

MIT — see [LICENSE](LICENSE).
