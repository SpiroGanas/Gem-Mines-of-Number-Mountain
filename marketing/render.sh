#!/usr/bin/env bash
# Renders the store graphics from the SVG sources (P3-S26-01) with Godot's own SVG rasterizer, so no
# extra tool is needed. Works in Git Bash on Windows and on Linux.
#
#   GODOT=/path/to/Godot_v4.7.2-stable ./marketing/render.sh
#
# Writes marketing/export/icon-512.png (32-bit, 512 x 512) and marketing/export/feature-1024x500.png
# (no transparency, 1024 x 500). Alternatives if Godot is not at hand: `rsvg-convert -w 512 -h 512
# -o out.png in.svg`, or Inkscape's `--export-type=png --export-width=512`.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT to the pinned Godot 4.7 executable}"
render() {
	"$GODOT" --headless --path . --script res://tools/marketing/render_svg.gd -- "$@"
}
render marketing/src/icon.svg marketing/export/icon-512.png 512 512
render marketing/src/feature.svg marketing/export/feature-1024x500.png 1024 500 --opaque
