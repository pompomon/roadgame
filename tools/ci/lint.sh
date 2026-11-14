#!/usr/bin/env bash
# Style (gdlint, gdformat), the determinism rule (IMPLEMENTATION_PLAN.md §5.3), shell scripts,
# version pins and the Actions storage policy (no caches, artifacts kept 1 day; docs/M0.md F34).
# Needs gdtoolkit (pip install -r tools/ci/requirements.txt), not Godot.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

# Only pass directories that exist: gdlint fails on missing paths, and grep exits 2 on them.
gd_list=(autoload road world car disasters areas setpieces ui config tests tools audio)
gd_dirs=()
for d in "${gd_list[@]}"; do
  if [ -d "$d" ]; then gd_dirs+=("$d"); fi
done
[ "${#gd_dirs[@]}" -gt 0 ] || { echo "::error::No GDScript directories found"; exit 1; }
# A script anywhere else would skip every check here (docs/M5.md L16): list its directory above.
stray=$(find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' \
  | grep -vE "^\./($(IFS='|'; echo "${gd_list[*]}"))/" || true)
[ -z "$stray" ] || { echo "::error::GDScript outside the linted directories:"; echo "$stray"; exit 1; }
gdlint "${gd_dirs[@]}"
gdformat --check "${gd_dirs[@]}"

# Determinism: gameplay code must use seeded RandomNumberGenerator streams. Flags bare global RNG
# calls (rng.randf() is fine) and Array.shuffle()/pick_random(). Text in string literals and
# comments never counts, nor does the name in a func declaration (its one-line body does).
rng_re='(^|[^.[:alnum:]_])(randf|randi|randfn|randf_range|randi_range|randomize|seed|rand_from_seed)[[:space:]]*\(|\.(shuffle|pick_random)[[:space:]]*\('
gameplay_dirs=()
for d in autoload road world car disasters areas setpieces; do
  if [ -d "$d" ]; then gameplay_dirs+=("$d"); fi
done
if [ "${#gameplay_dirs[@]}" -gt 0 ]; then
  candidates="$REPORTS/rng_candidates.txt"
  hits="$REPORTS/rng_hits.txt"
  rc=0
  grep -rlE --include='*.gd' "$rng_re" "${gameplay_dirs[@]}" > "$candidates" || rc=$?
  [ "$rc" -le 1 ] || { echo "::error::Determinism check could not scan gameplay code"; exit 1; }
  files=()
  while IFS= read -r f; do files+=("$f"); done < "$candidates"
  : > "$hits"
  if [ "${#files[@]}" -gt 0 ]; then
    # Lex each candidate file as GDScript does: a backslash escapes the next character in every
    # string kind, and triple-quoted or backslash-continued strings span lines. String literals
    # become "", comments and declared func names are dropped, and the rest of each line is
    # matched again. \047 is a single quote.
    RNG_RE="$rng_re" awk '
      function str_end(s, d,    i) {
        for (i = 1; i <= length(s); i++) {
          if (substr(s, i, 1) == "\\") i++
          else if (substr(s, i, length(d)) == d) return i + length(d)
        }
        return 0
      }
      FNR == 1 { open = "" }
      {
        rest = $0; code = ""
        while (rest != "") {
          if (open != "") {
            i = str_end(rest, open)
            if (i == 0) break
            code = code "\"\""; rest = substr(rest, i); open = ""
          } else if (match(rest, /[#"\047]/)) {
            code = code substr(rest, 1, RSTART - 1)
            c = substr(rest, RSTART, 1)
            if (c == "#") break
            open = c
            if (substr(rest, RSTART, 3) == c c c) open = c c c
            rest = substr(rest, RSTART + length(open))
          } else {
            code = code rest; rest = ""
          }
        }
        sub(/^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+[[:alnum:]_]+/, "func", code)
        if (code ~ ENVIRON["RNG_RE"]) print FILENAME ":" FNR ":" $0
      }' "${files[@]}" > "$hits"
  fi
  if [ -s "$hits" ]; then
    cat "$hits"
    echo "::error::Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)"
    exit 1
  fi
fi

if command -v shellcheck > /dev/null 2>&1; then
  shellcheck -x tools/ci/*.sh tools/agent/*.sh
else
  echo "warning: shellcheck not found; shell scripts not checked" >&2
fi

tools/ci/check_versions.sh
tools/ci/check_actions_storage.sh
