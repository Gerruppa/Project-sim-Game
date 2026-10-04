#!/usr/bin/env bash
# Runs the gdUnit4 test suite headless.
# Usage: GODOT_BIN=/path/to/godot ./run_tests.sh [gdUnit4 args, default: -a res://simulation/tests]
set -u

if [ -z "${GODOT_BIN:-}" ]; then
	echo "GODOT_BIN is not set. Point it to the Godot 4.7.2 console binary." >&2
	exit 1
fi

cd "$(dirname "$0")"

args=("$@")
if [ ${#args[@]} -eq 0 ]; then
	args=(-a res://simulation/tests)
fi

# The class cache must exist before tests can resolve class_name types.
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1

"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c "${args[@]}"
exit_code=$?

# 0 = success, 100 = failures, 101 = warnings. Anything but 0 fails the run.
echo "gdUnit4 exit code: $exit_code"
exit $exit_code
