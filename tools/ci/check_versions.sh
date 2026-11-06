#!/usr/bin/env bash
# The Godot version must match everywhere: godot-ci image tags, the Copilot setup workflow and
# project.godot config/features (version bump procedure: IMPLEMENTATION_PLAN.md §7.1).
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

rc=0
# Capture the complete tag, so 4.7.2-rc1, latest or an expression never passes as 4.7.2.
tags=$(grep -rhoE 'barichello/godot-ci:[[:alnum:]_.-]*' .github | sort -u) || rc=$?
[ "$rc" -le 1 ] || { echo "::error::Could not scan .github/"; exit 1; }
[ -n "$tags" ] || { echo "::error::No barichello/godot-ci image tag under .github/"; exit 1; }
if [ "$(printf '%s\n' "$tags" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "::error::Mismatched godot-ci image tags:"
  printf '%s\n' "$tags"
  exit 1
fi
version="${tags#*:}"
printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || { echo "::error::Pin godot-ci to a full x.y.z tag (found '$version')"; exit 1; }
minor="${version%.*}"
grep -qF "config/features=PackedStringArray(\"$minor\"" project.godot \
  || { echo "::error::project.godot config/features must start with \"$minor\""; exit 1; }
setup=.github/workflows/copilot-setup-steps.yml
if [ -f "$setup" ]; then
  grep -qF "GODOT_VERSION: \"$version\"" "$setup" \
    || { echo "::error::$setup must set GODOT_VERSION: \"$version\""; exit 1; }
fi
echo "Godot $version is pinned consistently"
