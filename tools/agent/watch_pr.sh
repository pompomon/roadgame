#!/usr/bin/env bash
# Watch a pull request for new review feedback after a push (docs/agents/review.md §3).
# Needs gh, logged in.
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: tools/agent/watch_pr.sh <pr> [--minutes 15] [--interval 60] [--repo owner/name]

Polls the PR every --interval seconds for up to --minutes. Prints each review, inline comment and
PR comment that appears while it runs, and stops one poll after Copilot's review of the head
commit is in. --minutes 0 only prints the current state.

Exit codes:
  0  Copilot reviewed the head commit, nothing that needs an answer arrived, and no check failed
     but Copilot's own (checks may still be running: the summary says). Or the PR is closed, even
     if feedback came with that (printed above)
  2  Feedback that needs an answer (printed above the summary): anything new but a clean Copilot
     review, or Copilot's review of the head that was already there, isn't clean, and has no
     thread reply or post by anyone but Copilot after it. Handle it, push, reply, run this again.
     If the head moved too, the last line says so: pull first
  3  No Copilot review of the head commit in time (docs/agents/review.md §3 says what to do)
  4  The head commit changed while watching, and nothing new needs an answer: pull, run this again
  5  A check other than Copilot's own failed on the head commit (named in the summary;
     docs/agents/review.md §4)
  1  Usage error, or gh failed 3 times in a row
EOF
}

pr="" minutes=15 interval=60 repo=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --minutes | --interval | --repo)
      [ "$#" -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in
        --minutes) minutes="$2" ;;
        --interval) interval="$2" ;;
        *) repo="$2" ;;
      esac
      shift 2
      ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; exit 1 ;;
    *)
      [ -z "$pr" ] || { usage >&2; exit 1; }
      pr="$1"
      shift
      ;;
  esac
done
for n in "$pr" "$minutes" "$interval"; do
  case "$n" in '' | *[!0-9]*) usage >&2; exit 1 ;; esac
done
[ "$interval" -ge 10 ] || { echo "--interval must be at least 10 seconds" >&2; exit 1; }

# Runs "$@" up to 3 times, 10 s apart, until it succeeds.
try3() {
  local attempt
  for attempt in 1 2 3; do
    if "$@"; then return 0; fi
    [ "$attempt" -eq 3 ] || { echo "warning: gh failed ($attempt of 3), retrying in 10 s" >&2; sleep 10; }
  done
  return 1
}
gh_down() { echo "Exit 1: gh failed 3 times in a row." >&2; exit 1; }

find_repo() { repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner); }
[ -n "$repo" ] || try3 find_repo || gh_down

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tab=$(printf '\t')

# Each feedback item is one line: key, time, author, text, URL, separated by tabs. Bodies lose
# their HTML and line breaks and are cut to 300 characters. Comment-only reviews without a body
# are the containers of thread replies; their comments are listed on their own. A sixth field
# marks Copilot's reviews of any commit, "true" if clean (approval recommended, no open or
# previously missed issues) and "false" if not; and thread replies, "reply", whoever posted them
# (the cloud agent replies as Copilot, like Copilot's own inline comments, but those never reply
# in a thread). Reviews have a seventh, the commit they review, so one request finds both the new
# items and Copilot's review of the head.
jq_text='def text: (. // "") | gsub("<[^>]*>"; "") | gsub("\\s+"; " ") | ltrimstr(" ") | .[0:300];'
items() {
  gh api --paginate "repos/$repo/pulls/$pr/reviews?per_page=100" --jq "$jq_text"'
    .[] | select(.state != "PENDING" and ((.body // "") != "" or .state != "COMMENTED"))
    | ["review-\(.id)", (.submitted_at // ""), .user.login,
       "review of \(.commit_id[0:7])\(if .state == "COMMENTED" then ""
                                       else " (\(.state | ascii_downcase))" end): \(.body | text)",
       .html_url,
       if .user.login | startswith("copilot-pull-request-reviewer")
       then .body // "" | test("Approval recommended") and test("No open issues")
                          and (test("previously missed") | not) | tostring
       else "" end,
       .commit_id // ""] | @tsv' &&
    gh api --paginate "repos/$repo/pulls/$pr/comments?per_page=100" --jq "$jq_text"'
    .[] | ["inline-\(.id)", .created_at, .user.login,
           "\(.path):\(.line // .original_line // "?"): \(.body | text)", .html_url,
           if .in_reply_to_id then "reply" else "" end] | @tsv' &&
    gh api --paginate "repos/$repo/issues/$pr/comments?per_page=100" --jq "$jq_text"'
    .[] | ["comment-\(.id)", .created_at, .user.login, (.body | text), .html_url] | @tsv'
}

# Copilot's latest review of the head commit, from the items: id, whether it is clean, text.
head_review() {
  awk -F '\t' -v head="$head" '($6 == "true" || $6 == "false") && $7 == head {
                 r = substr($1, 8) "\t" $6 "\t" substr($4, index($4, ": ") + 2) }
               END { if (r != "") print r }' "$tmp/all"
}

pr_state() { gh api "repos/$repo/pulls/$pr" --jq '"\(.state) \(.merged) \(.head.sha)"'; }

show() {
  LC_ALL=C sort -t "$tab" -k2,2 "$1" | awk -F '\t' '{ printf "  %s  %s: %s\n      %s\n", $2, $3, $4, $5 }'
}

# The PR's state and head, when the head was committed, and the feedback so far.
start_state() {
  info=$(pr_state) || return 1
  read -r state merged head <<< "$info"
  since=$(gh api "repos/$repo/commits/$head" --jq .commit.committer.date) || return 1
  items > "$tmp/all"
}
try3 start_state || gh_down
short=${head:0:7}
cut -f1 "$tmp/all" | LC_ALL=C sort > "$tmp/seen"
review=$(head_review)
echo "Watching $repo#$pr ($state) at $short for up to $minutes min, polling every $interval s."
awk -F '\t' -v since="$since" '$2 >= since' "$tmp/all" > "$tmp/recent"
if [ -s "$tmp/recent" ]; then
  echo "Already there, since $short was committed ($since):"
  show "$tmp/recent"
fi

start=$(date +%s)
deadline=$((start + minutes * 60))
reviewed="" polls_after_review=0 attention=0 moved="" failures=0
if [ -n "$review" ]; then
  reviewed=1
  echo "Copilot had already reviewed $short."
  # Started late: unless that review is clean, it needs an answer if nothing but Copilot's own
  # feedback came after it.
  if [ "$state" = open ] && [ "$(printf '%s' "$review" | cut -f2)" != true ]; then
    at=$(awk -F '\t' -v k="review-$(printf '%s' "$review" | cut -f1)" '$1 == k { print $2 }' "$tmp/all")
    if ! awk -F '\t' -v at="$at" '$2 > at && ($6 == "reply" ||
           ($3 != "Copilot" && $3 !~ /^copilot-pull-request-reviewer/)) { found = 1 }
           END { exit !found }' "$tmp/all"; then
      attention=1
      echo "It isn't clean, and nothing but Copilot's feedback came after it: it needs an answer."
    fi
  fi
fi

while [ "$state" = open ]; do
  now=$(date +%s)
  if [ -n "$reviewed" ] && [ "$polls_after_review" -ge 1 ]; then break; fi
  [ "$now" -lt "$deadline" ] || break
  nap=$interval
  [ $((now + nap)) -le "$deadline" ] || nap=$((deadline - now))
  sleep "$nap"
  if ! { info=$(pr_state) && items > "$tmp/poll"; }; then
    failures=$((failures + 1))
    echo "warning: gh failed ($failures in a row)" >&2
    [ "$failures" -lt 3 ] || gh_down
    continue
  fi
  failures=0
  mv "$tmp/poll" "$tmp/all"
  review=$(head_review)
  read -r state merged new_head <<< "$info"
  cut -f1 "$tmp/all" | LC_ALL=C sort > "$tmp/keys"
  LC_ALL=C comm -13 "$tmp/seen" "$tmp/keys" > "$tmp/new"
  mv "$tmp/keys" "$tmp/seen"
  if [ -s "$tmp/new" ]; then
    awk -F '\t' 'NR == FNR { new[$1] = 1; next } $1 in new' "$tmp/new" "$tmp/all" > "$tmp/items"
    echo "New at $(date -u +%H:%M:%S) UTC:"
    show "$tmp/items"
    # A clean Copilot review needs no answer, whichever commit it reviews; anything else does.
    if awk -F '\t' '$6 != "true" { found = 1 } END { exit !found }' "$tmp/items"; then
      attention=1
    fi
  fi
  if [ -n "$reviewed" ]; then
    polls_after_review=$((polls_after_review + 1))
  elif [ -n "$review" ]; then
    reviewed=1
  fi
  if [ "$new_head" != "$head" ]; then
    moved=$new_head
    break
  fi
done

elapsed=$(($(date +%s) - start))
echo "== $repo#$pr at $short after $((elapsed / 60)) min $((elapsed % 60)) s: $state, merged: $merged"
if [ -n "$review" ]; then
  echo "Copilot's review of $short: $(printf '%s' "$review" | cut -f3)"
else
  echo "Copilot's review of $short: none yet"
fi
# The head's check runs, all pages: status, conclusion, name. Copilot's own check doesn't make
# this exit 5: its setup failures also arrive as a PR comment (docs/agents/review.md §2).
read_checks() {
  gh api --paginate "repos/$repo/commits/$head/check-runs?per_page=100" \
    --jq '.check_runs[] | [.status, (.conclusion // ""), .name] | @tsv' > "$tmp/checks"
}
checks_read=""
if try3 read_checks; then checks_read=1; fi
commas() { awk 'NR > 1 { printf ", " } { printf "%s", $0 } END { if (NR) print "" }'; }
failed=""
if [ -n "$checks_read" ]; then
  counts=$(awk -F '\t' '{ print ($2 != "" ? $2 : $1) }' "$tmp/checks" | LC_ALL=C sort | uniq -c \
    | awk '{ print $1 " " $2 }' | commas)
  echo "Checks on $short: ${counts:-none yet}"
  awk -F '\t' '$1 == "completed" && $2 !~ /^(success|skipped|neutral)$/ { print $3 }' \
    "$tmp/checks" | LC_ALL=C sort -u > "$tmp/failed"
  [ ! -s "$tmp/failed" ] || echo "Failed checks: $(commas < "$tmp/failed")"
  failed=$(grep -v '^copilot-pull-request-reviewer' "$tmp/failed" | commas || true)
else
  echo "Checks on $short: unknown, gh failed 3 times"
fi
if [ "$state" != open ]; then
  if [ "$attention" -eq 1 ]; then
    echo "Exit 0: the PR is $state, so there's nothing to push. Read the feedback above: it may ask for a follow-up."
  else
    echo "Exit 0: the PR is $state."
  fi
  exit 0
elif [ "$attention" -eq 1 ]; then
  # Feedback before a moved head: a new run lists only what came after the new head's commit, and
  # looks only for Copilot's review of that head, so it could miss this feedback.
  if [ -n "$moved" ]; then
    echo "Exit 2: feedback that needs an answer, printed above, and someone pushed ${moved:0:7}. Pull it, handle each item, push, reply, then run this again."
  else
    echo "Exit 2: feedback that needs an answer, printed above. Handle each item, push, reply, then run this again."
  fi
  exit 2
elif [ -n "$moved" ]; then
  echo "Exit 4: the head moved to ${moved:0:7}. Pull it, then run this again."
  exit 4
elif [ -z "$checks_read" ]; then
  echo "Exit 1: could not read the checks of $short. Check gh auth status, then run this again." >&2
  exit 1
elif [ -n "$failed" ]; then
  echo "Exit 5: a check failed on $short. Read its log (docs/agents/review.md §4), fix or re-run, then run this again."
  exit 5
elif [ -z "$review" ]; then
  echo "Exit 3: no Copilot review of $short within $minutes min."
  exit 3
fi
echo "Exit 0: Copilot reviewed $short, and nothing new needs an answer."
