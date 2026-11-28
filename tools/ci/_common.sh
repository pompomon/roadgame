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

# godot_user_dir: prints the project's user://, where Godot 4.7.2 keeps it (get_data_path() in
# os_linuxbsd.cpp and os_macos.mm). On Linux, under XDG_DATA_HOME if that is an absolute path, or
# else under HOME/.local/share, or without HOME under XDG_CONFIG_HOME if that is absolute, or else
# under the working directory; on macOS, under HOME/Library/Application Support, or without HOME
# under the working directory. An empty HOME counts as set, and String::path_join() then leaves
# the path relative to the working directory.
godot_user_dir() {
  local data
  if [ "$(uname -s)" = Darwin ]; then
    if [ -n "${HOME+set}" ]; then
      data="${HOME:+$HOME/}Library/Application Support"
    else
      data=.
    fi
    data="$data/Godot"
  else
    case "${XDG_DATA_HOME:-}" in
      /*) data="$XDG_DATA_HOME" ;;
      *)
        if [ -n "${HOME+set}" ]; then
          data="${HOME:+$HOME/}.local/share"
        else
          case "${XDG_CONFIG_HOME:-}" in
            /*) data="$XDG_CONFIG_HOME" ;;
            *) data=. ;;
          esac
        fi
        ;;
    esac
    data="$data/godot"
  fi
  printf '%s\n' "$data/app_userdata/Road Roguelike"
}

# fresh_gut_versions: keeps GUT's editor plugin from checking for updates in the editor runs that
# follow. A day after its last check, the plugin fetches GUT's versions.json from GitHub's API, and
# a failure there, such as a 401 or a 403 for the rate limit, is an ERROR line that fail_on rejects
# (addons/gut/gut_plugin.gd:82-84, update_detector.gd:195; docs/M0.md Q1). So this writes GUT's own
# copy where the plugin keeps the fetched one (update_detector.gd:31), dated now. It replaces the
# file whole, as an editor in another worktree shares this user:// and may be reading it.
fresh_gut_versions() {
  local dir now tmp
  dir="$(godot_user_dir)/gut_temp_directory"
  now=$(date +%s)
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/versions.json.XXXXXX")
  sed "1s/^{\$/{\"fetch_timestamp\": $now,/" addons/gut/versions.json > "$tmp"
  if [ "$(head -n 1 "$tmp")" != "{\"fetch_timestamp\": $now," ]; then
    rm -f "$tmp"
    echo "::error::addons/gut/versions.json no longer starts with a lone {, so GUT would check for updates"
    return 1
  fi
  mv -f "$tmp" "$dir/versions.json"
}

# scratch_save: gives the Godot runs that follow a scratch user:// whose save.json isn't JSON, which
# reading it would rename to .bak (docs/M5.md L1).
scratch_save() {
  SCRATCH_DIR=$(mktemp -d)
  # Absolute, as Godot ignores a relative XDG_DATA_HOME, which would make SAVE_DIR the real user://.
  case "$SCRATCH_DIR" in /*) ;; *) SCRATCH_DIR="$PWD/$SCRATCH_DIR" ;; esac
  if [ "$(uname -s)" = Darwin ]; then
    export HOME="$SCRATCH_DIR"
  else
    export XDG_DATA_HOME="$SCRATCH_DIR"
  fi
  SAVE_DIR=$(godot_user_dir)
  mkdir -p "$SAVE_DIR"
  echo "not a save" > "$SAVE_DIR/save.json"
}

# check_scratch_save <who> <log>: fails if <who> read or wrote the scratch save, or if Godot kept
# user:// elsewhere, as its log there shows, where the scratch save proves nothing. Then removes it.
check_scratch_save() {
  if [ ! -s "$SAVE_DIR/logs/godot.log" ]; then
    echo "::error::Godot kept user:// outside $SAVE_DIR, so the save there proves nothing (see $2)"
    return 1
  fi
  if [ "$(cat "$SAVE_DIR/save.json")" != "not a save" ] || [ -e "$SAVE_DIR/save.json.bak" ]; then
    echo "::error::$1 read or wrote the save file (see $2)"
    return 1
  fi
  rm -rf "$SCRATCH_DIR"
}
