#!/usr/bin/env bash
# Shared setup for tools/ci/*.sh: source it, do not run it. Works with bash 3.2+ (macOS) and
# GNU or BSD tools. Use another Godot binary with GODOT=/path/to/godot.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

GODOT="${GODOT:-godot}"
REPORTS="build/reports"
mkdir -p "$REPORTS"
# Stop the editor from importing build outputs (index.png, ...) into the project.
[ -f build/.gdignore ] || : > build/.gdignore

# A GDScript file failed to parse or load (warnings set to "error" are reported the same way).
SCRIPT_ERROR_RE='Parse Error|Failed to load script'
# Any engine or script error. Godot exits 0 after most runtime errors, so logs must be scanned.
# shellcheck disable=SC2034 # used by the scripts that source this file
ANY_ERROR_RE="^(SCRIPT |USER )?ERROR:|$SCRIPT_ERROR_RE"
# Known harmless error lines, never counted by fail_on (whole-line match). The godot-ci image has
# no fontconfig, so editor runs (--import) cannot look up system fonts; the project uses none.
IGNORE_RE='ERROR: Unable to load fontconfig, system font support is disabled\.'

TIMEOUT_BIN=""
if command -v timeout > /dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  echo "warning: no 'timeout' command (macOS: brew install coreutils); Godot runs have no time limit" >&2
fi

# run_godot <seconds> <log> <godot args...>
# Runs Godot with a time limit (a -s script that hits an error before quit() never exits),
# copies its output to <log> and returns Godot's exit code (124 = timed out).
run_godot() {
  local secs="$1" log="$2" rc=0
  shift 2
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" -k 10 "$secs" "$GODOT" "$@" 2>&1 | tee "$log" || rc=$?
  else
    "$GODOT" "$@" 2>&1 | tee "$log" || rc=$?
  fi
  [ "$rc" -ne 124 ] || echo "::error::Godot did not finish within ${secs}s (see $log)"
  return "$rc"
}

# fail_on <regex> <log> <message>: print the matching lines and fail if <log> matches <regex>.
# Lines that match IGNORE_RE are skipped.
fail_on() {
  local hits rc=0
  hits=$(grep -nE "$1" "$2") || rc=$?
  [ "$rc" -le 1 ] || { echo "::error::Could not read $2"; return 1; }
  hits=$(printf '%s\n' "$hits" | grep -vE "^[0-9]+:($IGNORE_RE)\$") || true
  [ -n "$hits" ] || return 0
  printf '%s\n' "$hits"
  echo "::error::$3 (see $2)"
  return 1
}
