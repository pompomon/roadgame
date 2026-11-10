#!/usr/bin/env bash
# Boot the real main scene for 3600 fixed frames (60 s simulated) and fail on any error.
# With --autopilot the main scene drives by itself and, when it quits, prints how far it got.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/smoke.log"
# The autopilot keeps the save in memory (M5_PLAN.md L1). On Linux, Godot keeps user:// under
# XDG_DATA_HOME: the run gets one whose save.json isn't JSON, which reading it would rename to .bak.
data_home=$(mktemp -d)
save_dir="$data_home/godot/app_userdata/Road Roguelike"
mkdir -p "$save_dir"
echo "not a save" > "$save_dir/save.json"
export XDG_DATA_HOME="$data_home"
run_godot 300 "$log" --headless --path . --fixed-fps 60 --quit-after 3600 -- --autopilot --seed=12345
fail_on "$ANY_ERROR_RE" "$log" "Errors during smoke run"
if [ "$(cat "$save_dir/save.json")" != "not a save" ] || [ -e "$save_dir/save.json.bak" ]; then
  echo "::error::The autopilot read or wrote the save file (see $log)"
  exit 1
fi
rm -rf "$data_home"
if ! grep -E '^autopilot: tile [1-9]' "$log"; then
  echo "::error::The main scene reported no autopilot progress (see $log)"
  exit 1
fi
