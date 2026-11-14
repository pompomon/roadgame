#!/usr/bin/env bash
# Run every GUT test and write build/reports/gut-junit.xml. GUT exits 0 when a test script does
# not parse or the project was never imported, so the log and the JUnit total are checked too.
# The post-run hook tests/gut_post_run.gd makes GUT exit 1 on errors in setup/teardown hooks.
# Arguments choose which tests run, with the same checks (AGENTS.md §3). Only GUT's options for that
# are taken, so that no run can drop the config's hooks or the errors that fail a test:
# -gselect=test_hud runs each script whose file name contains test_hud, and
# -gdir= -gtest=res://tests/unit/test_hud.gd,res://tests/integration/test_crash.gd runs just those.
for arg in "$@"; do
  case "$arg" in
    -gselect=* | -gtest=* | -gdir=* | -ginner_class=* | -gunit_test_name=*) ;;
    *)
      echo "::error::run_tests.sh takes only -gselect=, -gtest=, -gdir=, -ginner_class= and -gunit_test_name=, not: $arg"
      exit 2
      ;;
  esac
done
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/gut.log"
junit="$REPORTS/gut-junit.xml"
rm -f "$junit"
# The tests keep the save in memory (docs/M5.md L1), from tests/gut_pre_run.gd on, which no test
# can check once another has called SaveService.use_memory(). As smoke.sh's autopilot does, they
# must leave a scratch save be.
scratch_save
rc=0
run_godot 900 "$log" --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json -gjunit_xml_file="$junit" -gexit "$@" || rc=$?

fail_on "$SCRIPT_ERROR_RE|have not been imported|\\[GUT ERROR\\]" "$log" "GUT could not load every test"
[ "$rc" -eq 0 ] || { echo "::error::GUT reported failures (exit $rc)"; exit "$rc"; }
[ -s "$junit" ] || { echo "::error::GUT wrote no JUnit report ($junit)"; exit 1; }
total=$(sed -n 's/.*<testsuites[^>]* tests="\([0-9][0-9]*\)".*/\1/p' "$junit" | head -n 1)
[ "${total:-0}" -gt 0 ] || { echo "::error::GUT ran 0 tests"; exit 1; }
fail_on "ObjectDB instances? (was|were) leaked|resources? still in use at exit" "$log" \
  "Objects leaked at exit: a cycle of RefCounted references, or a node that is never freed"
check_scratch_save "The tests" "$log"
echo "GUT: $total tests passed"
