#!/usr/bin/env bash
# Boot the real main scene for 3600 fixed frames (60 s simulated) and fail on any error.
# With --autopilot the main scene fast-forwards and, when it quits, prints how far it got.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/smoke.log"
run_godot 300 "$log" --headless --path . --fixed-fps 60 --quit-after 3600 -- --autopilot --seed=12345
fail_on "$ANY_ERROR_RE" "$log" "Errors during smoke run"
if ! grep -E '^autopilot: tile [1-9]' "$log"; then
  echo "::error::The main scene reported no autopilot progress (see $log)"
  exit 1
fi
