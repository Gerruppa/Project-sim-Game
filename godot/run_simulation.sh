#!/usr/bin/env bash
# Runs the simulation in the console (headless).
# Usage: GODOT_BIN=/path/to/godot ./run_simulation.sh [options] (options: USAGE in game/simulation_runner.gd)
# Logs: logs/simulation_runs/<run id>.log, .jsonl, .chronicle.txt; saves: saves/
set -u

if [ -z "${GODOT_BIN:-}" ]; then
	echo "GODOT_BIN is not set. Point it to the Godot 4.7.2 console binary." >&2
	exit 1
fi

cd "$(dirname "$0")"

# The class cache must exist before scripts can resolve class_name types.
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1

"$GODOT_BIN" --headless --path . -s res://tools/run_simulation.gd -- "$@"
