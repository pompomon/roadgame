#!/usr/bin/env bash
# Load every project GDScript and fail on parse errors, including warnings set to "error"
# (untyped_declaration). Neither --import nor GUT fails on these.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/check_scripts.log"
run_godot 300 "$log" --headless --path . -s res://tools/ci/check_scripts.gd
fail_on "$ANY_ERROR_RE" "$log" "GDScript errors"
grep -qE '^check_scripts: loaded [1-9][0-9]* scripts' "$log" \
  || { echo "::error::check_scripts.gd did not finish (see $log)"; exit 1; }
