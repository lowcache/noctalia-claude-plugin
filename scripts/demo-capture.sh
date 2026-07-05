#!/usr/bin/env -S nix shell nixpkgs#slurp nixpkgs#wf-recorder nixpkgs#ffmpeg nixpkgs#gifski --command bash
# demo-capture.sh — one-command region → optimized GIF, for the C3P-No demo.
#
#   ./scripts/demo-capture.sh                 # → assets/demo.gif
#   ./scripts/demo-capture.sh my.gif          # → my.gif
#   FPS=30 WIDTH=1100 ./scripts/demo-capture.sh
#
# Flow: drag a box (slurp) over the bar dot + orb (park the orb under the bar
# first), perform the /c3 ? question→answer arc, press Ctrl-C to stop. Out comes
# a scaled, quantized GIF via gifski.
#
# The shebang provisions slurp/wf-recorder/ffmpeg/gifski through `nix shell`, so
# no manual dev-shell is needed. Requires flakes (nix-command) enabled.
set -euo pipefail

FPS="${FPS:-24}"
WIDTH="${WIDTH:-900}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-$REPO/assets/demo.gif}"
mkdir -p "$(dirname "$OUT")"

# Belt-and-suspenders in case the script is run without the nix-shell shebang.
missing=0
for t in slurp wf-recorder ffmpeg gifski; do
  command -v "$t" >/dev/null 2>&1 || { echo "missing: $t" >&2; missing=1; }
done
if [ "$missing" = 1 ]; then
  echo "Run via the shebang (./scripts/demo-capture.sh) or:" >&2
  echo "  nix shell nixpkgs#slurp nixpkgs#wf-recorder nixpkgs#ffmpeg nixpkgs#gifski --command ./scripts/demo-capture.sh" >&2
  exit 1
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
raw="$tmp/raw.mp4"

geom="$(slurp)" || { echo "region selection cancelled." >&2; exit 1; }

echo "▶ recording ${geom} — press Ctrl-C to stop…" >&2
# Absorb the Ctrl-C in the shell so the script survives to encode; the same
# SIGINT reaches wf-recorder, which finalizes the file and exits.
trap 'echo' INT
wf-recorder -g "$geom" -f "$raw" || true
trap - INT

if [ ! -s "$raw" ]; then
  cat >&2 <<'EOF'
✗ nothing captured. wf-recorder needs the wlr-screencopy protocol; if this niri
  build doesn't expose it, use the portal-based fallback:
      nix run nixpkgs#kooha      # GUI: Selection → record → export GIF
EOF
  exit 1
fi

echo "● encoding GIF (fps=${FPS} width=${WIDTH})…" >&2
ffmpeg -loglevel error -i "$raw" -vf "fps=${FPS}" "$tmp/f_%05d.png"
gifski --quiet --fps "$FPS" --width "$WIDTH" -o "$OUT" "$tmp"/f_*.png

echo "✓ ${OUT} ($(du -h "$OUT" | cut -f1))" >&2
