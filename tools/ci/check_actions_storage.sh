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

# A step is a list item plus the more indented lines below it. Its inputs are the keys right
# under its with: mapping, so env: entries and run: text don't count. Block scalars (run: | and
# the like) are text, searched only for type=gha. Keys are compared in lowercase, since GitHub
# ignores the case of input names. Comments, quotes, anchors and tags are dropped (Cache: &c
# "pip" is cache: pip). What the check can't read fails: uses: in flow style ({...} or [...],
# also over several lines), a with: that is not a block mapping, ? keys, escaped keys, an input
# set twice, and a uses:, cache input or retention-days whose value is on the lines below, an
# alias or escaped. \047 is a single quote.
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
  # A value the check cannot read: on the lines below its key, an alias or escaped.
  function unread(n, k) {
    print FILENAME ":" n ": " k ": write the value on the same line, without aliases or escapes"
    inputs[k] = "?"                          # so that end_step does not report it again
  }
  function noprops(s) {                      # drops anchors (&a) and tags (!!str)
    while (s ~ /^[&!]/) sub(/^[&!][^ \t]*[ \t]*/, "", s)
    return s
  }
  function end_step(    k, r) {
    if (s_line) {
      r = inputs["retention-days"]
      if (s_uses ~ /^actions\/upload-(artifact(\/merge)?|pages-artifact)$/ \
          && r != "1" && r != "?")
        print s_file ":" s_line ": " s_uses " must set retention-days: 1"
      # A missing or empty input means the default, which caches. Other values are checked
      # where they are set.
      if (s_uses in dflt) {
        k = dflt[s_uses]
        if (inputs[k] == "")
          print s_file ":" s_line ": " s_uses " caches unless it sets " k ": " off[k]
      }
    }
    s_line = 0; s_uses = ""; s_key = -1; w_ind = -1; split("", inputs)
  }
  FNR == 1 { end_step(); bs = -1; p_key = ""; fd = 0 }
  {
    line = $0
    sub(/(^|[ \t])#.*/, "", line); sub(/[ \t\r]+$/, "", line)
    if (line == "") next
    if (line ~ /type=gha/)
      print FILENAME ":" FNR ": type=gha stores Docker layers in the Actions cache"
    match(line, /^ */); ind = RLENGTH
    if (bs >= 0 && ind > bs) next            # the text of a block scalar
    bs = -1

    match(line, /^ *(- +)*/); col = RLENGTH  # where the content starts, after any dashes
    rest = noprops(substr(line, col + 1)); key = ""; val = rest
    if (match(rest, /^["\047]?[A-Za-z0-9_.-]+["\047]?[ \t]*:/) \
        && substr(rest, RLENGTH + 1, 1) ~ /^[ \t]?$/) {
      key = tolower(substr(rest, 1, RLENGTH - 1)); gsub(/["\047 \t]/, "", key)
      val = substr(rest, RLENGTH + 1)
    }
    sub(/^[ \t]+/, "", val); val = noprops(val)
    # Flow style ({...} or [...], which may go on over the lines below): its keys are not read.
    # fd counts the brackets still open, leaving out quoted text.
    f = (fd > 0) ? rest : ((val ~ /^[[{]/) ? val : "")
    if (f != "") {
      if (tolower(f) ~ /(^|[[{,])[ \t]*["\047]?uses["\047]?[ \t]*:/)
        print FILENAME ":" FNR ": uses: must be in a block mapping, one key per line"
      t = $0; gsub(/"([^"\\]|\\.)*"|\047[^\047]*\047/, "", t); sub(/(^|[ \t])#.*/, "", t)
      fd += gsub(/[[{]/, "", t) - gsub(/[]}]/, "", t)
      if (fd < 0) fd = 0
    }
    if (rest ~ /^[?]([ \t]|$)/ || f ~ /[[{,][ \t]*[?]([ \t]|$)/)
      print FILENAME ":" FNR ": ? key: write it as key: value"
    if (line ~ /"([^"\\]|\\.)*\\.([^"\\]|\\.)*"[ \t]*:([ \t]|$)/)
      print FILENAME ":" FNR ": write the key without escapes"
    # The value of the key on the line above (key:, then the value further indented).
    if (p_key != "" && ind > p_col && col == ind && key == "" && rest != "-")
      unread(p_line, p_key)
    p_key = ""

    if (s_line && ind <= s_ind) end_step()
    if (rest == "-" || rest == "") {         # a list item or a node that starts on the next line
      if (!s_line && (rest == "-" || col > ind)) { s_line = FNR; s_ind = ind; s_file = FILENAME }
      next
    }
    if (!s_line && col > ind) { s_line = FNR; s_ind = ind; s_file = FILENAME }
    if (s_line && s_key < 0) s_key = col
    if (val ~ /^[|>][-+0-9]*$/) bs = (key != "") ? col : ind
    hidden = (val ~ /^([|>][-+0-9]*|[*].*)$/ || val ~ /^"[^"]*\\/)   # block scalar, alias, escape
    gsub(/["\047]/, "", val)

    if (key == "uses") {
      u = ""
      if (hidden) unread(FNR, key)
      else if (val == "") { p_key = key; p_col = col; p_line = FNR }
      else { u = tolower(val); sub(/@.*/, "", u) }
      if (u ~ /cache/) print FILENAME ":" FNR ": " u " stores a cache"
    }
    if (!s_line) next
    if (col == s_key) {                      # a key of the step: uses, with, env, run, ...
      w_ind = -1
      if (key == "uses") s_uses = u
      if (key == "with" && val != "")
        print FILENAME ":" FNR ": with: must be a block mapping, one input per line"
      else if (key == "with") { w_ind = col; w_col = -1 }
    } else if (w_ind >= 0 && ind > w_ind) {
      if (w_col < 0) w_col = ind
      if (ind == w_col && col == ind && key != "") {   # an input of the step
        if (key in inputs)
          print FILENAME ":" FNR ": " key ": set it only once (input names ignore case)"
        inputs[key] = tolower(val)
        if ((key in off) || key == "retention-days") {
          if (hidden) unread(FNR, key)
          else if (val == "") { p_key = key; p_col = col; p_line = FNR }
          else if ((key in off) && tolower(val) != off[key])
            print FILENAME ":" FNR ": " key ": " val " turns on a cache"
        }
      }
    }
  }
  END { end_step() }' "${files[@]}")

if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "::error::Caches or long-lived artifacts break the Actions storage policy (M0_PLAN.md F34)"
  exit 1
fi
echo "Actions storage: no caches, artifacts kept 1 day (${#files[@]} files checked)"
