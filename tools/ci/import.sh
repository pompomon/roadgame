#!/usr/bin/env bash
# Import all resources so .godot/ (imported assets, global class cache) exists; GUT and exports
# need it. --import does not report GDScript errors; check_scripts.sh covers those.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

run_godot 900 "$REPORTS/import.log" --headless --path . --import
fail_on "$ANY_ERROR_RE" "$REPORTS/import.log" "Errors during import"
