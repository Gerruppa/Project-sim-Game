#!/usr/bin/env bash
# Builds the tester package: GenesisError.exe (Windows, single file) and the
# tester guide in build/GenesisError-<date>-<commit>.zip.
# Needs the Godot 4.7.2 Windows export templates installed (Editor > Manage
# Export Templates, or unpack the official .tpz into
# %APPDATA%/Godot/export_templates/4.7.2.stable).
# Usage: GODOT_BIN=/path/to/godot ./export_game.sh
set -eu

if [ -z "${GODOT_BIN:-}" ]; then
	echo "GODOT_BIN is not set. Point it to the Godot 4.7.2 binary." >&2
	exit 1
fi

cd "$(dirname "$0")"
build="../build"
package="GenesisError-$(date +%Y-%m-%d)-$(git rev-parse --short HEAD)"
mkdir -p "$build/$package"

"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1
"$GODOT_BIN" --headless --path . --export-release "Windows Desktop" "$build/$package/GenesisError.exe" > /dev/null 2>&1
if [ ! -s "$build/$package/GenesisError.exe" ]; then
	echo "Export failed (are the export templates installed?)." >&2
	exit 1
fi
# Windows line endings, so the guide reads well in every editor.
sed 's/$/\r/' ../docs/instrukcja_testera.txt > "$build/$package/INSTRUKCJA.txt"

(cd "$build" && rm -f "$package.zip" && python -m zipfile -c "$package.zip" "$package")
echo "$build/$package.zip"
