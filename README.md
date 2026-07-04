# Claude Code Companion (Noctalia v5)

What Claude Code lacks as a terminal agent is any awareness of your desktop — it can't see your windows, can't send a notification, and gives no ambient signal when it's waiting on you. This plugin fixes that by wiring noctalia into Claude's lifecycle: a bar pulse that tracks every active session, a presence orb on the desktop, and a one-shot ask panel that pops answers inline. The terminal still does all the agentic work (permissions, tools, MCP all native) — this just gives it a body.

**v1.0.0** — built and live-tested against noctalia 5.0.0 (flake input `623210223c`). Ships the `pulse` bar widget with multi-session token telemetry, the `orb` desktop widget with sine-breath animation, the `answer` panel for `/cc ?` quick-asks, and an agent-agnostic pulse protocol ([PROTOCOL.md](PROTOCOL.md)) with a generic `pulse-emit` adapter. 54 offline widget specs pass under the nix test harness.

---

## How it fits together

Three moving parts, each with a role:

**Perceive** — `shim/noctalia-mcp.py` gives Claude a read on your running environment via `niri msg -j`, `playerctl`, and `noctalia msg status`. When you launch via `/cc`, the shim is wired in automatically.

**Act** — `cc.luau` is the `/cc` launcher provider and the single backend chokepoint (`invoke`/`parse`, normalized event vocabulary). It also drives `notify-send` for toasts and `noctalia msg` for panel actions.

**Pulse** — `pulse.luau` receives Claude Code's hook events via IPC and is the sole aggregator: tracks every session, renders the most urgent state, breathes the accent color, and mirrors the rollup to `noctalia.state` (`cc.pulse`) so the orb and answer panel can subscribe.

`orb.luau` is a pure view — it subscribes to `cc.pulse` and breathes the same state via per-frame ticks (sine-driven opacity + glyph scale, tempo keyed to urgency). No hooks of its own. `answer.luau` is the `[[panel]]` that carries `/cc ?` answers in full, wrapped and scrollable where a toast would clip.

---

## The pulse widget must stay on a bar

This is the one thing that'll burn you if you miss it: the `pulse` bar widget is the aggregator for the whole system. It receives the hook IPC events and publishes `cc.pulse` state. Noctalia bar widgets only run while placed on a bar, and noctalia 5.0.0 has no headless service entry — so if you remove `pulse` from your bar, the plugin goes silent. Hooks keep firing, nobody listens, state freezes.

Symptom: bar icon gone or stuck, orb breathes the same state forever, manual `noctalia msg plugin lowcache/claude:pulse …` pokes do nothing. Fix: put the `pulse` widget back on a bar in noctalia's settings.

---

## Install

```sh
# 1. clone and symlink into the plugins dir
ln -s "$PWD" ~/.local/share/noctalia/plugins/claude

# 2. enable the plugin
noctalia msg plugins enable lowcache/claude
```

3. **Add the `pulse` widget to a bar** (Settings → Bar) — not optional, see above.
4. Optionally add `orb` as a desktop widget for the ambient presence.
5. Merge `hooks/settings.snippet.json` into `~/.claude/settings.json` so Claude Code's lifecycle hooks drive the pulse.
6. Point Claude at `shim/noctalia-mcp.py` via `--mcp-config` to expose desktop senses and hands. (`/cc`-launched sessions do this automatically.)

Smoke test once you're set up:

```sh
noctalia msg plugin lowcache/claude:pulse all needs_attention
# bar icon → red bell

noctalia msg plugin lowcache/claude:pulse all idle
# back to robot
```

---

## Usage

- `/cc <task>` — launch a Claude Code TUI session in the terminal, noctalia MCP shim wired in.
- `/cc` — resume the last session (`claude --continue`), same wiring.
- `/cc ? <question>` — one-shot read-only ask. Answer arrives as a toast preview and is published to the answer panel. Open the panel via the bar pulse, the "Show last answer" row under `/cc`, or `noctalia msg panel-open lowcache/claude:answer`. While the panel is open it refreshes live and the toast is suppressed — one surface per answer. Dismiss with a click outside or Esc.

The bar tooltip shows per-session state and token burn (input / output / cache reads). With several sessions running it lists each one plus a Σ total, and the icon reflects the most urgent state across all of them.

---

## Driving the pulse from other agents

The pulse wire format is agent-agnostic — the widget just consumes events and doesn't care what produced them. Any agent, CI job, or script that can run a shell command on its lifecycle can light up the same bar. See [PROTOCOL.md](PROTOCOL.md) for the eight-event vocabulary, CSV payload, session semantics, and adapter contract. `hooks/pulse-emit` is the reference emitter — plain POSIX sh, no dependencies beyond `noctalia` on PATH:

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
- The shim's memory tool drops notes into `~/.memory/inbox` for the memd curator. Without memd installed it's inert — files are written, nothing reads them. The contract it implements is memd's Inbox Protocol v1.0 (`INBOX-PROTOCOL.md` in the memd repo).

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
