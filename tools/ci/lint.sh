#!/usr/bin/env bash
# Style (gdlint, gdformat), the determinism rule (IMPLEMENTATION_PLAN.md §5.3), shell scripts
# and version pins. Needs gdtoolkit (pip install -r tools/ci/requirements.txt), not Godot.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

# Only pass directories that exist: gdlint fails on missing paths, and grep exits 2 on them.
gd_dirs=()
for d in autoload road world car disasters areas setpieces ui config tests tools; do
  if [ -d "$d" ]; then gd_dirs+=("$d"); fi
done
[ "${#gd_dirs[@]}" -gt 0 ] || { echo "::error::No GDScript directories found"; exit 1; }
gdlint "${gd_dirs[@]}"
gdformat --check "${gd_dirs[@]}"

# Determinism: gameplay code must use seeded RandomNumberGenerator streams. Flags bare global RNG
# calls (rng.randf() is fine) and Array.shuffle()/pick_random(); skips comments and func lines.
rng_re='(^|[^.[:alnum:]_])(randf|randi|randfn|randf_range|randi_range|randomize|seed|rand_from_seed)[[:space:]]*\(|\.(shuffle|pick_random)[[:space:]]*\('
gameplay_dirs=()
for d in autoload road world car disasters areas setpieces; do
  if [ -d "$d" ]; then gameplay_dirs+=("$d"); fi
done
if [ "${#gameplay_dirs[@]}" -gt 0 ]; then
  hits="$REPORTS/rng_hits.txt"
  rc=0
  grep -rnE --include='*.gd' "$rng_re" "${gameplay_dirs[@]}" > "$hits" || rc=$?
  [ "$rc" -le 1 ] || { echo "::error::Determinism check could not scan gameplay code"; exit 1; }
  if grep -vE '^[^:]+:[0-9]+:[[:space:]]*(#|func[[:space:]])' "$hits"; then
    echo "::error::Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)"
    exit 1
  fi
fi

if command -v shellcheck > /dev/null 2>&1; then
  shellcheck -x tools/ci/*.sh
else
  echo "warning: shellcheck not found; shell scripts not checked" >&2
fi

tools/ci/check_versions.sh
