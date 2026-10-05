#!/usr/bin/env bash
# Plays Genesis Error in the console: menu, hints and decision points.
# Usage: GODOT_BIN=/path/to/godot ./play.sh [--seed N] [--personality NAME] [--load FILE] [--no-hints]
# Guide: docs/jak_grac.md
set -u

if [ -z "${GODOT_BIN:-}" ]; then
	echo "GODOT_BIN is not set. Point it to the Godot 4.7.2 console binary." >&2
	exit 1
fi

cd "$(dirname "$0")"

# The class cache must exist before scripts can resolve class_name types.
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1

"$GODOT_BIN" --headless --path . -s res://tools/play.gd -- "$@"
