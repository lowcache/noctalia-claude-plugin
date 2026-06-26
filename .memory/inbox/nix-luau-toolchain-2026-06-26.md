---
routed: noctalia-claude-plugin
topic: nix-luau-toolchain
date: 2026-06-26
source: claude/session
---

NEW: offline luau test toolchain under nix/ — fold into state.md (new "Development / testing" facet) and decisions.md (a luau testing harness now exists; widget logic no longer needs a noctalia reload to regression-test).

WHY: pulse.luau was previously only verifiable by a Python port of its logic or a full noctalia widget reload (persistent subprocess). Now validated by a real luau interpreter offline.

WHAT:
- nix/flake.nix — self-contained flake (input: nixpkgs-unstable, pinned rev 89570f2 / 2026-06-23 in nix/flake.lock). Provides devShells.default (luau + pulse-test on PATH), apps.default/test (`nix run ./nix#test`), packages.pulse-test. luau resolved to 0.725 from cache.nixos.org.
- tests/prelude.luau — stubs barWidget{setGlyph,setGlyphColor,setTooltip} + noctalia.state.watch; records __tt/__glyph/__color; expect()/done() harness (done() raises error() for non-zero exit on failure since luau CLI lacks os.exit).
- tests/spec.luau — 9 specs driving the public surface (global onIpc + barWidget stub).
- Runner concatenates prelude + pulse.luau + spec into ONE luau chunk (so the real source is tested, not a copy; single-chunk = the spec also has white-box access to pulse.luau's top-level locals). Operates on the working tree at $PWD.
- README "Development" section + .gitignore (result, result-*).

KEY NIX GOTCHA (decision-worthy): a flake living UNDER nix/ is sealed to its own dir and CANNOT reference ../pulse.luau, so a pure `nix flake check` of the widget is impossible from there. Worked around by having the runner read the working tree from $PWD instead of a sealed `self` copy — correct for a dev harness (tests files you're editing) but means the test is not hermetic. If a hermetic CI check is ever wanted, the flake must move to the repo root. Also: nix only sees git-TRACKED (or staged) files — new flake files must be `git add`-ed (staged, not committed) before `nix flake lock`/`run` sees them.

RESULT: `nix run ./nix#test` → all 9 specs pass under luau 0.725. `nix develop ./nix` → luau + pulse-test on PATH, pulse-test PASS. This supersedes the earlier Python-port validation of pulse.luau — the formatting/state-machine logic is now confirmed by genuine luau execution (full payload tooltip "opus-4-8 · 247.5k in / 112.4k out · 4.6M cached"; idle clears burn; no-cache omits segment; unknown state → idle fallback).

NOT committed (commit-only-when-asked). Staged for nix visibility: nix/flake.nix, nix/flake.lock, tests/prelude.luau, tests/spec.luau, hooks/pulse.py. Unstaged mods: pulse.luau, hooks/settings.snippet.json, README.md, .gitignore.
