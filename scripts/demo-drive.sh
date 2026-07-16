#!/usr/bin/env bash
# demo-drive.sh — animate the pulse bar dot + desktop orb through a full Claude
# lifecycle arc, at recording pace, for the Claude Companion demo GIF.
#
#   ./scripts/demo-drive.sh            # one arc, ~3s lead-in, then idle→…→done→needs-you
#   HOLD=1.8 ./scripts/demo-drive.sh   # faster (seconds each state is held)
#   LOOP=1  ./scripts/demo-drive.sh    # cycle forever until Ctrl-C (frame while it runs)
#   LEAD=5  ./scripts/demo-drive.sh    # longer countdown before the arc starts
#
# Why this exists: the bar dot's glyph/color/breath and the desktop orb are both
# driven by pulse events. The orb subscribes to the "claude.pulse" shared state that
# the bar republishes on every event, so ONE stream of pokes moves both surfaces.
# Each poke carries a real-looking CSV payload (fixed session id + climbing token
# burn) so the tooltip + orb telemetry read as a live session, not a bare test.
#
#   noctalia msg plugin lowcache/claude-companion:pulse all <event> <model,in,out,cc,cr,sid>
#
# Do the `/claude ? …` question→answer arc yourself (that drives its own state); run
# this to make the ambient widgets breathe through their states for the capture.
set -euo pipefail

PLUGIN="lowcache/claude-companion:pulse"
SID="${SID:-demo}"
MODEL="${MODEL:-opus-4-8}"
HOLD="${HOLD:-2.4}"     # seconds each state is held (breath is visible within this)
LEAD="${LEAD:-3}"       # countdown seconds before the arc, to arm the recorder
LOOP="${LOOP:-}"        # non-empty → repeat the arc until Ctrl-C

command -v noctalia >/dev/null 2>&1 || { echo "✗ noctalia not on PATH" >&2; exit 1; }

# poke <event> <in> <out> <cacheCreate> <cacheRead>
poke() {
  local ev="$1" tin="$2" tout="$3" cc="$4" cr="$5"
  noctalia msg plugin "$PLUGIN" all "$ev" "$MODEL,$tin,$tout,$cc,$cr,$SID" >/dev/null
}

cleanup() {
  # Retire the demo session so no phantom lingers on the bar/orb after recording.
  noctalia msg plugin "$PLUGIN" all session_end "$MODEL,0,0,0,0,$SID" >/dev/null 2>&1 || true
  echo
  echo "✓ demo session retired."
}
trap cleanup EXIT INT

arc() {
  # event            in   out    cc     cr     ← token burn climbs across the arc
  poke idle            0     0      0      0 ; sleep "$HOLD"   # robot,  slow breath
  poke turn_start   1200     0   8000      0 ; sleep "$HOLD"   # brain,  thinking
  poke tool_start   1500   340   8000  15000 ; sleep "$HOLD"   # tool,   running a tool
  poke turn_start   1800   900  12000  42000 ; sleep "$HOLD"   # brain,  thinking again
  poke text         1800  2600  12000  68000 ; sleep "$HOLD"   # message,responding
  poke turn_end     2000  4100  15000  95000 ; sleep "$HOLD"   # bell,   done — ready
  poke needs_attention 2000 4100 15000 95000 ; sleep "$HOLD"   # bell-ring, needs you (fast breath)
}

if [ "$LEAD" -gt 0 ] 2>/dev/null; then
  echo "▶ starting in… "
  for i in $(seq "$LEAD" -1 1); do printf '  %d\n' "$i"; sleep 1; done
fi

if [ -n "$LOOP" ]; then
  echo "● looping the arc (HOLD=${HOLD}s) — Ctrl-C to stop and retire the session."
  while true; do arc; done
else
  echo "● one arc (HOLD=${HOLD}s)…"
  arc
fi
