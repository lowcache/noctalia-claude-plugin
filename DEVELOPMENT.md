# Development

Offline gates for the plugin. Nothing here runs Noctalia: the live shell is where
*behaviour* is confirmed, this is where *syntax and contract* are. Both matter — the
one bug that ever took this plugin down on load was a syntax-level mistake that no
amount of live testing would have caught, because the shell simply refused to load the
service and said nothing.

## The shell

```sh
nix develop          # or `direnv allow` once, then it is automatic
make check           # the gates
```

Without Nix: you need `luau` (for `luau-analyze`) and `python3` on PATH. Everything
else is optional.

## The gates

`make check` runs four, and `nix flake check` runs the same four hermetically:

| Gate | What it catches |
| --- | --- |
| `make syntax` | `luau-analyze` — parse errors, type errors, unknown globals, unused locals |
| `make specs` | the Python suites under `tests/` |
| `make widgets` | the Luau widget suites — each entry run headless against a stubbed host |
| `make i18n` | a `tr()` key or manifest `label_key` with no entry in `translations/en.json` |

`make widgets` is the one that runs the code rather than reading it. A suite is a
prelude (stubs `noctalia`/`ui`/`barWidget`…, records what the widget applied), the
entry itself, and a spec, concatenated in that order and handed to `luau`; the spec
asserts on the recorded tooltip, glyph, colour and dispatched command. The suite list
lives in `scripts/run-widget-specs.sh`, which is also what `nix/flake.nix` drives for
the per-widget runners (`nix run ./nix#orb` and friends) — one list, three callers.

### Why `luau-analyze` is the important one

v1.4.0 shipped a call to `mirror_mode()` placed *above* its own `local function`
declaration. In Lua that is not an error at parse time — the name resolves to a global
read, which is `nil` at call time. The result was a service that threw on its first
publish and never loaded, for everyone, whether or not they used the feature it
belonged to. It was caught by reading the file, which is not a strategy.

`luau-analyze` catches exactly that shape:

```
regress.luau(3,3): TypeError: Unknown global 'mirror_mode'; consider assigning to it first
regress.luau(6,16): LocalShadow: Variable 'mirror_mode' shadows a global variable used at line 3
```

and exits non-zero. That behaviour is the reason this toolchain exists; if you change
the gate, keep that case working.

### `noctalia.d.luau`

Plugin entries run against globals the host injects (`noctalia`, `ui`, `panel`,
`barWidget`, `desktopWidget`, `launcher`). Without a definitions file, `luau-analyze`
reports every one of them as an unknown global — about forty lines of noise that bury
the one finding that matters.

`noctalia.d.luau` declares that surface, pinned against **Noctalia 5.0.0**, and is
passed via `--definitions=`. When the host gains an API, add it there rather than
silencing the lint. It is input to the analyser, never a target of it, so it is
excluded from the file list in both the `Makefile` and `flake.nix`.

`.luaurc` turns off `FunctionUnused`, because every entry point (`onIpc`, `onOpen`,
`update`, …) is called by the host and is by definition never used locally.

## Two tools that are deliberately not gates

**selene is not used.** It looked like the obvious linter and it is not usable here:
selene 0.31's config accepts only `config`, `lints`, `std`, `exclude` and
`roblox-std-source` — there is no Luau syntax option, and the build parses Lua 5.1.
Every `.luau` file in this repo fails to parse, and it reports that as a summary line
while still printing warnings for what it managed to read. A linter that silently
half-parses is worse than no linter. If a future selene gains Luau syntax support this
is worth revisiting; until then, `luau-analyze` covers the same ground and more.

**stylua is available but not a gate.** `make fmt` runs it. It is not in `make check`
because it wants to reformat all eight entries, and the layout in this repo is
deliberate: the comment blocks, the aligned tables and the one-line
`if x then y end` guards are how these files stay readable at 300 lines with no module
system to break them up. Run it if you want; read the diff before you keep it.

## Live testing

The gates cannot tell you whether a panel renders or an IPC event lands. For that:

```sh
ln -s "$PWD" ~/.local/share/noctalia/plugins/claude-companion
noctalia msg plugins enable lowcache/claude-companion

# reload after an edit
noctalia msg plugins disable lowcache/claude-companion
noctalia msg plugins enable  lowcache/claude-companion
```

A service that fails to load is *silent*. The cheapest liveness probe is a dispatch —
`ok: dispatched 1` means the runtime is up:

```sh
noctalia msg plugin lowcache/claude-companion:pulse-svc all idle
```

Note that `noctalia msg status` exposes only `barVisible/panelOpen/activePanelId/locked`;
plugin state (`claude.pulse`, `claude.consent`) is not readable from the CLI, so
anything published there has to be confirmed on a surface.

## The consent gate, while developing

It ships `off`. In `learn` it records without ever blocking, which is the safe mode to
develop against. Its own state lives in two places:

```sh
$XDG_RUNTIME_DIR/claude-companion/mode          # mirrored from the plugin setting
$XDG_RUNTIME_DIR/claude-companion/learn.jsonl   # observations (ephemeral)
$XDG_STATE_HOME/noctalia/claude-companion/allow.jsonl   # the allowlist (durable)
```

Drive the hook directly rather than waiting for a real tool call:

```sh
echo '{"tool_name":"Bash","tool_input":{"command":"ls"},"tool_use_id":"t1",
       "cwd":"/tmp","session_id":"dev-0001","permission_mode":"default"}' \
  | python3 hooks/consent.py
```

In `learn` that must print **nothing** — silence is Claude Code's "proceed normally",
and it is the property most of `tests/consent_spec.py` exists to pin.
