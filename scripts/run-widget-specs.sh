#!/usr/bin/env bash
# The Luau widget spec suites — the gate that runs the entries, not just parses them.
#
# A suite is three files concatenated in one order and handed to luau: the
# prelude (stubs the noctalia host API and records what the widget applied),
# then the entry under test, then the spec. The order IS the harness — the
# prelude's globals have to exist by the time the entry's top-level state.watch
# and first render execute, and the spec asserts on what the stubs recorded.
#
# The tr() fixture is regenerated from translations/en.json on every run, so the
# specs assert the strings actually shipped and cannot drift from them.
#
# One suite list, three consumers: `make widgets`, the root flake's
# checks.widget-specs, and nix/flake.nix's per-suite `nix run ./nix#orb`
# runners. Adding a suite here is the only edit a new widget needs.
set -euo pipefail

root="${1:-$PWD}"

# prelude : entry-under-test : spec
SUITES=(
  "tests/pulse_svc_prelude.luau:pulse-svc.luau:tests/pulse_svc_spec.luau"
  "tests/prelude.luau:pulse.luau:tests/spec.luau"
  "tests/orb_prelude.luau:orb.luau:tests/orb_spec.luau"
  "tests/answer_prelude.luau:answer.luau:tests/answer_spec.luau"
  "tests/sessions_prelude.luau:sessions.luau:tests/sessions_spec.luau"
)

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Every suite runs even after one fails: a spec break usually lands in more than
# one widget at once, and seeing all of them beats fixing them one run apiece.
fail=0
for suite in "${SUITES[@]}"; do
  IFS=: read -r prelude entry spec <<<"$suite"
  echo "-- ${entry%.luau}"
  for f in "$prelude" "$entry" "$spec"; do
    if [ ! -f "$root/$f" ]; then
      echo "   missing $root/$f (run from the repo root, or pass it as \$1)" >&2
      exit 2
    fi
  done
  python3 "$root/tests/gen_tr_fixture.py" "$root/translations/en.json" >"$tmp"
  cat "$root/$prelude" "$root/$entry" "$root/$spec" >>"$tmp"
  luau "$tmp" || fail=1
done

exit "$fail"
