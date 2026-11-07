#!/usr/bin/env bash
# Actions storage policy (M0_PLAN.md F34): no caches, and every artifact is kept 1 day. Scans the
# block-style YAML under .github/ for cache actions, cache inputs that are on (and actions that
# cache unless told not to), Docker layer caches (type=gha) and uploads without retention-days: 1.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

files=()
while IFS= read -r f; do files+=("$f"); done \
  < <(find .github -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
[ "${#files[@]}" -gt 0 ] || { echo "::error::No YAML files under .github/"; exit 1; }

# A step is a list item plus the more indented lines below it. Each line loses its comment,
# indentation, list dash and quotes (cache: "pip" becomes cache: pip); flow mappings such as
# with: {cache: pip} are not parsed. \047 is a single quote.
hits=$(awk '
  BEGIN {
    # Inputs that turn a cache on or off, and their off value.
    off["cache"] = "false"
    off["enable-cache"] = "false"
    off["package-manager-cache"] = "false"
    off["cache-binary"] = "false"
    off["cache-image"] = "false"
    off["cache-disabled"] = "true"
    off["no-cache"] = "true"
    # Actions that cache unless the step sets this input to its off value.
    dflt["actions/setup-go"] = "cache"
    dflt["actions/setup-node"] = "package-manager-cache"
    dflt["astral-sh/setup-uv"] = "enable-cache"
    dflt["chickensoft-games/setup-godot"] = "cache"
    dflt["docker/setup-buildx-action"] = "cache-binary"
    dflt["docker/setup-qemu-action"] = "cache-image"
    dflt["gradle/actions/setup-gradle"] = "cache-disabled"
    dflt["jdx/mise-action"] = "cache"
    dflt["oven-sh/setup-bun"] = "no-cache"
  }
  function end_step(    k) {
    if (s_line) {
      if (s_uses ~ /^actions\/upload-(artifact(\/merge)?|pages-artifact)$/ \
          && index(s_body "\n", "\nretention-days: 1\n") == 0)
        print s_file ":" s_line ": " s_uses " must set retention-days: 1"
      if (s_uses in dflt) {
        k = dflt[s_uses]
        if (index(s_body, "\n" k ":") == 0)
          print s_file ":" s_line ": " s_uses " caches unless it sets " k ": " off[k]
      }
    }
    s_line = 0; s_uses = ""; s_body = ""
  }
  FNR == 1 { end_step() }
  {
    line = $0
    sub(/(^|[ \t])#.*/, "", line)
    if (line ~ /^[ \t]*$/) next
    match(line, /^ */); ind = RLENGTH
    if (s_line && ind <= s_ind) end_step()
    if (!s_line && line ~ /^ *-( |$)/) { s_line = FNR; s_ind = ind; s_file = FILENAME }

    norm = line
    sub(/^ *-$/, "", norm); sub(/^ *(- +)?/, "", norm)
    gsub(/["\047]/, "", norm); gsub(/:[ \t]+/, ": ", norm); sub(/[ \t]+$/, "", norm)
    key = ""; val = ""
    if (match(norm, /^[A-Za-z0-9_.-]+:/) && substr(norm, RLENGTH + 1, 1) ~ /^ ?$/) {
      key = substr(norm, 1, RLENGTH - 1); val = substr(norm, RLENGTH + 2)
    }

    if (line ~ /type=gha/)
      print FILENAME ":" FNR ": type=gha stores Docker layers in the Actions cache"
    if (key == "uses") {
      u = tolower(val); sub(/@.*/, "", u)
      if (u ~ /cache/) print FILENAME ":" FNR ": " u " stores a cache"
      if (s_line) s_uses = u
    }
    if (s_line) {
      s_body = s_body "\n" norm
      if ((key in off) && val != "" && tolower(val) != off[key])
        print FILENAME ":" FNR ": " key ": " val " turns on a cache"
    }
  }
  END { end_step() }' "${files[@]}")

if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "::error::Caches or long-lived artifacts break the Actions storage policy (M0_PLAN.md F34)"
  exit 1
fi
echo "Actions storage: no caches, artifacts kept 1 day (${#files[@]} files checked)"
