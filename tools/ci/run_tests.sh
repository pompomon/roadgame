#!/usr/bin/env bash
# Run every GUT test and write build/reports/gut-junit.xml. GUT exits 0 when a test script does
# not parse or the project was never imported, so the log and the JUnit total are checked too.
# The post-run hook tests/gut_post_run.gd makes GUT exit 1 on errors in setup/teardown hooks.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/gut.log"
junit="$REPORTS/gut-junit.xml"
rm -f "$junit"
# The tests keep the save in memory (M5_PLAN.md L1), from tests/gut_pre_run.gd on, which no test
# can check once another has called SaveService.use_memory(). As in smoke.sh, they run with a
# user:// (on Linux, under XDG_DATA_HOME) whose save.json isn't JSON: reading it renames it.
data_home=$(mktemp -d)
save_dir="$data_home/godot/app_userdata/Road Roguelike"
mkdir -p "$save_dir"
echo "not a save" > "$save_dir/save.json"
export XDG_DATA_HOME="$data_home"
rc=0
run_godot 900 "$log" --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json -gjunit_xml_file="$junit" -gexit || rc=$?

fail_on "$SCRIPT_ERROR_RE|have not been imported|\\[GUT ERROR\\]" "$log" "GUT could not load every test"
[ "$rc" -eq 0 ] || { echo "::error::GUT reported failures (exit $rc)"; exit "$rc"; }
[ -s "$junit" ] || { echo "::error::GUT wrote no JUnit report ($junit)"; exit 1; }
total=$(sed -n 's/.*<testsuites[^>]* tests="\([0-9][0-9]*\)".*/\1/p' "$junit" | head -n 1)
[ "${total:-0}" -gt 0 ] || { echo "::error::GUT ran 0 tests"; exit 1; }
fail_on "ObjectDB instances? (was|were) leaked|resources? still in use at exit" "$log" \
  "Objects leaked at exit: a cycle of RefCounted references, or a node that is never freed"
if [ "$(cat "$save_dir/save.json")" != "not a save" ] || [ -e "$save_dir/save.json.bak" ]; then
  echo "::error::The tests read or wrote the save file (see $log)"
  exit 1
fi
rm -rf "$data_home"
echo "GUT: $total tests passed"
