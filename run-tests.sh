#!/usr/bin/env sh
set -eu
GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --quit
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/test_runner.gd
