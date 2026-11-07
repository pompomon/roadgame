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
# under its with: mapping, so env: entries and run: text don't count. Keys under an env: or
# with: block mapping are names: a variable or input called uses is not an action. A comment
# starts at a # after a blank, outside quoted text, as in YAML. Block scalars (run: | and the
# like) and text that goes on over several lines, quoted or plain, are text, searched only for
# type=gha (in any case, as buildx reads the key, and without the quotes and backslashes the
# shell removes, so type="gha" counts). Keys are compared in lowercase, since GitHub ignores the
# case of input names. Quotes, anchors and tags are dropped (Cache: &c "pip" is cache: pip).
# Quoted text is a value, never a key, unless a : follows it ({J: '{"uses": 1}'} has no uses:).
# What the check can't read fails: uses: in flow style ({...} or [...], also over several
# lines or after an anchor or tag), a with: that is not a block mapping (also on the lines below
# it), ? keys, alias keys (*k : x), escaped keys, an input set twice, and a uses:, cache input or
# retention-days whose value is on or goes on to the lines below, an alias or escaped. \047 is a
# single quote.
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
  # The line without its comment. A quote opens quoted text only where a node can start: at the
  # indent (unless plain text goes on there, cont), after "- ", "? ", ": ", an anchor or tag,
  # after [ { or , in flow style, and after a ":" right behind quoted text ({"a":"b"}). oq is the
  # quote still open at the end of the line and fd the number of flow brackets still open; both
  # go on to the next line. pl is set if the line ends in plain text, ns if it ends where a node
  # can start; lk is the last of - ? : on it and lc the column of that - or ?. um is the line
  # with the text of quoted values masked (mask()), to look for keys in.
  function uncomment(s, cont,    i, n, c, jq, qs) {
    n = length(s); ns = !cont; pl = cont; jq = 0; lk = ""; um = s; qs = 0
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (oq != "") {
        if (oq == "\"" && c == "\\") i++
        else if (c == oq && oq == "\047" && substr(s, i + 1, 1) == oq) i++
        else if (c == oq) { oq = ""; ns = 0; jq = 1; mask(qs, i, substr(s, i + 1)) }
      } else if (c == " " || c == "\t") {
        continue
      } else if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[ \t]/)) {
        pl = 0; um = substr(um, 1, i - 1); return substr(s, 1, i - 1)
      } else if (ns && (c == "\"" || c == "\047")) {
        oq = c; ns = 0; qs = i
      } else if (c == ":" && (jq || substr(s, i + 1, 1) ~ /^[ \t]?$/)) {
        ns = 1; jq = 0; pl = 0; lk = c
      } else if (ns && c ~ /[-?]/ && substr(s, i + 1, 1) ~ /^[ \t]?$/) {
        lk = c; lc = i - 1
      } else if (i == 1 && s ~ /^(---|[.][.][.])([ \t]|$)/) {
        i = 3                                # a document marker
      } else if (ns && c ~ /[&!]/) {
        while (i < n && substr(s, i + 1, 1) !~ /[ \t]/) i++
      } else if (ns && c ~ /[[{]/) {
        fd++
      } else if (fd && c ~ /[]}]/) {
        fd--; ns = 0; jq = 1; pl = 0
      } else if (fd && c == ",") {
        ns = 1; jq = 0; pl = 0
      } else {
        ns = 0; jq = 0; pl = 1
      }
    }
    if (oq != "") mask(qs, n + 1, "")
    return s
  }
  # Masks quoted text in um from quote `from` to quote `to` (0 and n + 1 if it goes on past the
  # line), unless a : follows it on the line (`after`), as after a quoted key.
  function mask(from, to, after,    t) {
    if (from > 0 && after ~ /^[ \t]*:/) return
    t = ""
    while (length(t) < to - from - 1) t = t "x"
    um = substr(um, 1, from) t substr(um, to)
  }
  # The shell drops quotes and backslashes: type="gha", t\ype=gha and $"gha" reach buildx as gha.
  function gha(s,    t) {
    t = tolower(s); gsub(/[$]?["\047]|\\/, "", t)
    if (t ~ /type=gha/)
      print FILENAME ":" FNR ": type=gha stores Docker layers in the Actions cache"
  }
  # Flow style ({...} or [...], which may go on over the lines below): its keys are not read.
  # An anchor or tag may come before a key ({&a uses: x}).
  function flow(s) {
    if (tolower(s) ~ /(^|[[{,])[ \t]*([&!][^ \t]*[ \t]+)*["\047]?uses["\047]?[ \t]*:/)
      print FILENAME ":" FNR ": uses: must be in a block mapping, one key per line"
    if (s ~ /[[{,][ \t]*[?]([ \t]|$)/) print FILENAME ":" FNR ": ? key: write it as key: value"
    if (s ~ /(^|[[{,])[ \t]*[*][^ \t,{}]*[ \t]*:/)
      print FILENAME ":" FNR ": write the key without aliases"
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
  FNR == 1 { end_step(); bs = -1; p_key = ""; fd = 0; oq = ""; ps = 0; pv = -1; d_ind = -1 }
  {
    raw = $0; sub(/[ \t\r]+$/, "", raw)
    fl = fd                                  # flow brackets still open from the lines above
    if (oq != "") {                          # quoted text that goes on from the line above
      line = uncomment(raw, 0); gha(line)
      if (fl > 0) flow(um)
      ps = pl && fd
      next
    }
    match(raw, /^ */); ind = RLENGTH
    if (bs >= 0 && (raw == "" || ind > bs)) { gha(raw); next }   # the text of a block scalar
    bs = -1
    if (raw == "") next
    # Plain text from the line above goes on here: always in flow style, and in block style if
    # the line is more indented than the parent of that text (pc).
    cont = ps && (fl > 0 || ind > pc)
    line = uncomment(raw, cont); sub(/[ \t]+$/, "", line); sub(/[ \t]+$/, "", um); ps = pl
    if (line == "") next
    gha(line)
    if (cont && fl == 0) {                   # the line is only text
      if (p_key != "") unread(p_line, p_key)
      p_key = ""; next
    }

    match(line, /^ *(-[ \t]+)*/); col = RLENGTH   # where the content starts, after any dashes
    if (d_ind >= 0 && ind <= d_ind) d_ind = -1   # the end of an env: or with: block mapping
    # The indent of the parent of plain text that may go on below (pc), and of a node that
    # starts on the next line (pv).
    if (ps && !fd) pc = (lk == "-") ? lc : (lk != "") ? col : (pv >= 0) ? pv : ind
    pv = (!ns || fd) ? -1 : (lk == "-") ? lc : (lk != "") ? col : pv
    rest = noprops(substr(line, col + 1)); key = ""; val = rest
    mrest = noprops(substr(um, col + 1)); mval = mrest    # the same, with quoted text masked
    if (match(rest, /^["\047]?[A-Za-z0-9_.-]+["\047]?[ \t]*:/) \
        && substr(rest, RLENGTH + 1, 1) ~ /^[ \t]?$/) {
      key = tolower(substr(rest, 1, RLENGTH - 1)); gsub(/["\047 \t]/, "", key)
      val = substr(rest, RLENGTH + 1); mval = substr(mrest, RLENGTH + 1)
    }
    sub(/^[ \t]+/, "", val); val = noprops(val); sub(/^[ \t]+/, "", mval); mval = noprops(mval)
    f = (fl > 0) ? mrest : ((val ~ /^[[{]/) ? mval : "")
    if (f != "") flow(f)
    if (rest ~ /^[?]([ \t]|$)/) print FILENAME ":" FNR ": ? key: write it as key: value"
    ak = (fl == 0 && rest ~ /^[*][^ \t]*[ \t]*:([ \t]|$)/)     # an alias key: *k : x
    if (ak) print FILENAME ":" FNR ": write the key without aliases"
    esc = (um ~ /"([^"\\]|\\.)*\\.([^"\\]|\\.)*"[ \t]*:([ \t]|$)/)
    if (esc) print FILENAME ":" FNR ": write the key without escapes"
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
    if (val ~ /^[|>][-+0-9]*$/) { bs = (key != "") ? col : ind; ps = 0 }
    hidden = (val ~ /^([|>][-+0-9]*|[*].*)$/ || val ~ /^"[^"]*\\/ || oq != "")
    gsub(/["\047]/, "", val)                 # hidden: a block scalar, alias, escape or open quote

    if (key == "uses" && d_ind < 0) {
      u = ""
      if (hidden) unread(FNR, key)
      else { p_key = key; p_col = col; p_line = FNR; u = tolower(val); sub(/@.*/, "", u) }
      if (u ~ /cache/) print FILENAME ":" FNR ": " u " stores a cache"
    }
    if ((key == "env" || key == "with") && val == "" && d_ind < 0) d_ind = col
    if (!s_line) next
    if (col == s_key) {                      # a key of the step: uses, with, env, run, ...
      w_ind = -1
      if (key == "uses") s_uses = u
      if (key == "with" && val != "")
        print FILENAME ":" FNR ": with: must be a block mapping, one input per line"
      else if (key == "with") { w_ind = col; w_col = -1 }
    } else if (w_ind >= 0 && ind > w_ind) {
      if (w_col < 0) w_col = ind
      if (ind == w_col && (col > ind || key == "")) {     # a list, flow, alias or scalar
        if (!esc && !ak)
          print FILENAME ":" FNR ": with: must be a block mapping, one input per line"
      } else if (ind == w_col) {                         # an input of the step
        if (key in inputs)
          print FILENAME ":" FNR ": " key ": set it only once (input names ignore case)"
        inputs[key] = tolower(val)
        if ((key in off) || key == "retention-days") {
          if (hidden) unread(FNR, key)
          else {
            p_key = key; p_col = col; p_line = FNR       # in case the value is on or goes on below
            if (val != "" && (key in off) && tolower(val) != off[key])
              print FILENAME ":" FNR ": " key ": " val " turns on a cache"
          }
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
