#!/usr/bin/env bash
# stamp_version.sh <[v]MAJOR.MINOR.PATCH>: write the version to project.godot
# (application/config/version) and the Android presets (version/name, version/code per D9).
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

v="${1:?usage: stamp_version.sh <[v]MAJOR.MINOR.PATCH>}"
v="${v#v}"
printf '%s' "$v" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' \
  || { echo "::error::Version '$v' must be MAJOR.MINOR.PATCH with each part 0-999 (D9)"; exit 1; }
IFS=. read -r major minor patch <<< "$v"
code=$((10#$major * 1000000 + 10#$minor * 1000 + 10#$patch))
[ "$code" -ge 1 ] || { echo "::error::Android version/code must be at least 1"; exit 1; }

# set_key <file> <key> <value>: replace every "<key>=..." line; fail if there is none.
set_key() {
  local tmp
  grep -q "^$2=" "$1" || { echo "::error::$1 has no '$2=' line"; exit 1; }
  tmp=$(mktemp)
  awk -v k="$2=" -v line="$2=$3" 'index($0, k) == 1 { print line; next } { print }' "$1" > "$tmp"
  cat "$tmp" > "$1"
  rm -f "$tmp"
}

set_key project.godot config/version "\"$v\""
set_key export_presets.cfg version/name "\"$v\""
set_key export_presets.cfg version/code "$code"
echo "Stamped version $v (Android version/code $code)"
