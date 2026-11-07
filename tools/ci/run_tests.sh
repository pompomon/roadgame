#!/usr/bin/env bash
# Run every GUT test and write build/reports/gut-junit.xml. GUT exits 0 when a test script does
# not parse or the project was never imported, so the log and the JUnit total are checked too.
# The post-run hook tests/gut_post_run.gd makes GUT exit 1 on errors in setup/teardown hooks.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/gut.log"
junit="$REPORTS/gut-junit.xml"
rm -f "$junit"
rc=0
run_godot 900 "$log" --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json -gjunit_xml_file="$junit" -gexit || rc=$?

fail_on "$SCRIPT_ERROR_RE|have not been imported|\\[GUT ERROR\\]" "$log" "GUT could not load every test"
[ "$rc" -eq 0 ] || { echo "::error::GUT reported failures (exit $rc)"; exit "$rc"; }
[ -s "$junit" ] || { echo "::error::GUT wrote no JUnit report ($junit)"; exit 1; }
total=$(sed -n 's/.*<testsuites[^>]* tests="\([0-9][0-9]*\)".*/\1/p' "$junit" | head -n 1)
[ "${total:-0}" -gt 0 ] || { echo "::error::GUT ran 0 tests"; exit 1; }
echo "GUT: $total tests passed"
