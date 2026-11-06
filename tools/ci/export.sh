#!/usr/bin/env bash
# export.sh <preset> <output> [debug|release]: export one preset and sanity-check the result.
# The log goes to build/reports, never next to the output (build/web is published).
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

usage="usage: export.sh <preset> <output> [debug|release]"
preset="${1:?$usage}"
out="${2:?$usage}"
mode="${3:-release}"
case "$mode" in
  debug | release) ;;
  *) echo "::error::$usage"; exit 1 ;;
esac

slug=$(printf '%s' "$preset" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-')
log="$REPORTS/export-$slug.log"
mkdir -p "$(dirname "$out")"
rm -f "$out"
if [ "$preset" = "Android AAB" ]; then
  # Gradle builds need res://android/build. The first Gradle run downloads its dependencies.
  run_godot 1800 "$log" --headless --path . --install-android-build-template \
    "--export-$mode" "$preset" "$out"
else
  run_godot 900 "$log" --headless --path . "--export-$mode" "$preset" "$out"
fi
fail_on "$ANY_ERROR_RE" "$log" "Errors during export of '$preset'"
[ -s "$out" ] || { echo "::error::Export '$preset' produced no file at $out (see $log)"; exit 1; }

case "$out" in
  *.html)
    for f in "${out%.html}.js" "${out%.html}.wasm" "${out%.html}.pck"; do
      [ -s "$f" ] || { echo "::error::Web export is missing $f"; exit 1; }
    done
    ;;
  *.apk | *.aab)
    # One entry per line, matched line by line. A here-string, because unzip | grep -q can
    # fail with SIGPIPE under pipefail.
    names=$(unzip -Z1 "$out")
    grep -qE '(^|/)lib/arm64-v8a/[^/]+\.so$' <<< "$names" \
      || { echo "::error::$out contains no arm64-v8a native library"; exit 1; }
    ;;
esac
echo "Exported '$preset' to $out"
