#!/usr/bin/env bash
# Land a PR of a plan that the owner approved, once its gate passes (docs/agents/stacks.md step 4).
# Needs gh, logged in.
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: tools/agent/land_pr.sh <pr> [--check] [--minutes 20] [--interval 60] [--repo owner/name]

Lands a PR of a plan whose plan PR the owner merged. It checks the gate (docs/agents/stacks.md
step 4) every --interval seconds, for up to --minutes while required checks or main's CI run are
still running, and squash-merges the PR with GitHub's default message, pinned to the head commit
that watch_pr.sh found reviewed. Then it retargets the open PRs still based on the PR's branch to
its base. --check only reports the gate.

Exit codes:
  0  Merged, or it already was. With --check: the gate passes, though checks may still be running
  2  The gate fails, or GitHub refused the merge: the reasons are printed. Fix them, or label the
     PR needs-owner and say why in a comment
  3  Required checks or main's CI run still running after --minutes: run this again
  1  Usage error, or gh failed 3 times in a row
EOF
}

pr="" minutes=20 interval=60 repo="" check=""
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
    --check) check=1; shift ;;
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
[[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { echo "Bad repository: $repo" >&2; exit 1; }
owner=${repo%/*} name=${repo#*/}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
here=$(cd "$(dirname "$0")" && pwd)
label=needs-owner
# Paths that change how agents work or how code is checked, and the list of finished plans, which
# a plan's summary adds to. The owner lands the PRs that change them (AGENTS.md §5).
owner_paths='^(AGENTS\.md$|\.github/|docs/agents/|docs/README\.md$|tools/ci/|tools/agent/|export_presets\.cfg$|addons/)'
commas() { awk 'NR > 1 { printf ", " } { printf "%s", $0 } END { if (NR) print "" }'; }

read_pr() {
  gh api "repos/$repo/pulls/$pr" --jq '.state, .merged, .draft, .base.ref, .head.ref, .head.sha,
    (.head.repo.full_name // ""), .mergeable_state, ([.labels[].name] | join(",")),
    (.merge_commit_sha // "")' > "$tmp/pr" || return 1
  { read -r state; read -r merged; read -r draft; read -r base; read -r head_ref; read -r head
    read -r head_repo; read -r mstate; read -r labels; read -r merge_sha; } < "$tmp/pr"
}

# The PR's open review threads: id, author of the first comment, path:line, URL.
# shellcheck disable=SC2016 # GraphQL's variables, not the shell's
threads_query='query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
    reviewThreads(first: 100, after: $endCursor) { pageInfo { hasNextPage endCursor }
      nodes { id isResolved path line comments(first: 1) { nodes { author { login } url } } } } } } }'
# The branches that the PR was based on before a retarget, by hand or by GitHub.
# shellcheck disable=SC2016 # GraphQL's variables, not the shell's
bases_query='query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
    timelineItems(itemTypes: [BASE_REF_CHANGED_EVENT, AUTOMATIC_BASE_CHANGE_SUCCEEDED_EVENT],
                  first: 100, after: $endCursor) { pageInfo { hasNextPage endCursor }
      nodes { ... on BaseRefChangedEvent { previousRefName }
              ... on AutomaticBaseChangeSucceededEvent { oldBase } } } } } }'
# The checks of the PR's head as GitHub's merge box sees them: only the PR's own runs, not runs
# started by hand or Copilot's (docs/DAYNIGHT.md §4.5). Head, id, name, status, conclusion and
# whether the base requires it.
# shellcheck disable=SC2016 # GraphQL's and jq's variables, not the shell's
rollup_query='query($owner: String!, $name: String!, $pr: Int!) {
  repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
    commits(last: 1) { nodes { commit { oid statusCheckRollup { contexts(first: 100) { nodes {
      __typename
      ... on CheckRun { databaseId name status conclusion isRequired(pullRequestNumber: $pr) }
      ... on StatusContext { context state isRequired(pullRequestNumber: $pr) } } } } } } } } } }'
# shellcheck disable=SC2016
rollup_jq='.data.repository.pullRequest.commits.nodes[0].commit | .oid as $oid
  | (.statusCheckRollup.contexts.nodes // [])[]
  | if .__typename == "CheckRun"
    then [$oid, (.databaseId | tostring), .name, .status, (.conclusion // ""), (.isRequired | tostring)]
    else [$oid, "0", .context, (if .state == "PENDING" or .state == "EXPECTED" then "PENDING"
                                else "COMPLETED" end), .state, (.isRequired | tostring)]
    end | @tsv'

# Copilot's reviewer, by its bot's type and exact login, as anyone can pick a login such as
# copilot-pull-request-reviewer-x (watch_pr.sh).
reviewer_jq='def reviewer: .user.type == "Bot" and .user.login == "copilot-pull-request-reviewer[bot]";'

# Every review, inline comment and PR comment: key, author, URL, and "copilot" for a review by
# Copilot's reviewer. Comment-only reviews without a body hold thread replies, which come as
# inline comments (watch_pr.sh).
feedback() {
  {
    gh api --paginate "repos/$repo/pulls/$pr/reviews?per_page=100" --jq "$reviewer_jq"' .[]
      | select(.state != "PENDING" and ((.body // "") != "" or .state != "COMMENTED"))
      | ["review-\(.id)", (.user.login // "ghost"), .html_url, (if reviewer then "copilot" else "" end)]
      | @tsv' &&
      gh api --paginate "repos/$repo/pulls/$pr/comments?per_page=100" \
        --jq '.[] | ["inline-\(.id)", (.user.login // "ghost"), .html_url] | @tsv' &&
      gh api --paginate "repos/$repo/issues/$pr/comments?per_page=100" \
        --jq '.[] | ["comment-\(.id)", (.user.login // "ghost"), .html_url] | @tsv'
  } > "$tmp/feedback"
}

ok() { printf '  ok    %s\n' "$*" >> "$tmp/report"; }
no() { printf '  no    %s\n' "$*" >> "$tmp/report"; fails=$((fails + 1)); }
waiting() { printf '  wait  %s\n' "$*" >> "$tmp/report"; waits=$((waits + 1)); }

# Checks the gate into $tmp/report, counting fails and waits, but for what pr_lines checks. Returns 1
# only when gh fails. It checks $head0, the head that the merge is pinned to.
gate() {
  : > "$tmp/report"
  fails=0 waits=0
  if [[ "$head_ref" =~ ^([A-Za-z0-9]+)/[0-9]+-[A-Za-z0-9._-]+$ ]]; then
    local prefix=${BASH_REMATCH[1]} plans
    plans=$(gh api "repos/$repo/pulls?state=closed&base=$default&head=$owner:$prefix/plan&per_page=100" \
      --jq '[.[] | select(.merged_at != null) | "#\(.number)"] | join(", ")') || return 1
    if [ -n "$plans" ]; then
      ok "the plan is approved: the owner merged $prefix/plan ($plans)"
    else
      no "the plan isn't approved: no PR from $prefix/plan has merged into $default"
    fi
  else
    no "$head_ref isn't a plan's PR, <prefix>/<k>-<slug>: the owner lands it"
  fi

  # PRs land bottom up. Retargeted before the PR below it landed, it would bring that PR in too.
  gh api graphql --paginate -f query="$bases_query" -F owner="$owner" -F name="$name" -F pr="$pr" \
    --jq '.data.repository.pullRequest.timelineItems.nodes[] | .previousRefName // .oldBase // empty' \
    > "$tmp/bases" || return 1
  LC_ALL=C sort -u -o "$tmp/bases" "$tmp/bases"
  local below landed
  while read -r below; do
    [ "$below" != "$default" ] || continue
    if ! [[ "$below" =~ ^[A-Za-z0-9._/-]+$ ]]; then
      no "it was based on $below, an odd branch name: the owner lands it"
      continue
    fi
    landed=$(gh api "repos/$repo/pulls?state=closed&base=$default&head=$owner:$below&per_page=100" \
      --jq '[.[] | select(.merged_at != null) | "#\(.number)"] | join(", ")') || return 1
    if [ -n "$landed" ]; then
      ok "it was based on $below, which has landed ($landed)"
    else
      no "it was based on $below, and no PR from it has merged into $default: PRs land bottom up (stacks.md step 4)"
    fi
  done < "$tmp/bases"

  gh api graphql --paginate -f query="$threads_query" -F owner="$owner" -F name="$name" -F pr="$pr" \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)
          | [.id, (.comments.nodes[0].author.login // "ghost"), "\(.path):\(.line // "?")",
             (.comments.nodes[0].url // "")] | @tsv' > "$tmp/threads" || return 1
  if [ -s "$tmp/threads" ]; then
    while IFS=$'\t' read -r id who where url; do
      no "open thread by $who at $where: $url (id $id)"
    done < "$tmp/threads"
  else
    ok "no open review thread"
  fi

  # main's tip, so that the compare and the CI run below are of the same commit.
  local tip behind nfiles
  tip=$(gh api "repos/$repo/git/ref/heads/$default" --jq .object.sha) || return 1
  [[ "$tip" =~ ^[0-9a-f]{40}$ ]] || return 1
  # The files come from the diff of main's tip and the head, not from the PR's: that is what the
  # merge brings into main, whatever the PR's base. GitHub lists up to 300 of them.
  gh api "repos/$repo/compare/$tip...$head0" \
    --jq '.behind_by, (.files | length), (.files[] | .filename, (.previous_filename // empty))' \
    > "$tmp/compare" || return 1
  { read -r behind && read -r nfiles; } < "$tmp/compare" || return 1
  case "$behind" in '' | *[!0-9]*) return 1 ;; esac
  case "$nfiles" in '' | *[!0-9]*) return 1 ;; esac
  if [ "$behind" -gt 0 ]; then
    no "$behind commits behind $default: merge it in (stacks.md step 5)"
  else
    ok "up to date with $default"
  fi
  tail -n +3 "$tmp/compare" | grep -E "$owner_paths" | LC_ALL=C sort -u > "$tmp/owner_files" || true
  if [ "$nfiles" -ge 300 ]; then
    no "its diff with $default has $nfiles files or more, more than GitHub lists: the owner lands it"
  elif [ -s "$tmp/owner_files" ]; then
    no "its diff with $default changes paths that the owner lands: $(head -n 5 "$tmp/owner_files" | commas)"
  else
    ok "its diff with $default changes none of the owner's paths, in $nfiles file(s)"
  fi

  # Whether main's rules make GitHub check again, at the merge, what the head pin doesn't cover: that
  # the PR is still up to date and has no open thread. Then the checks that they require.
  gh api "repos/$repo/rules/branches/$default?per_page=100" --jq '
    ([.[] | select(.type == "required_status_checks")
       | .parameters.strict_required_status_checks_policy] | any),
    ([.[] | select(.type == "pull_request") | .parameters.required_review_thread_resolution] | any),
    (.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context)' \
    > "$tmp/rules" || return 1
  local strict resolve
  { read -r strict && read -r resolve; } < "$tmp/rules" || return 1
  tail -n +3 "$tmp/rules" > "$tmp/required"
  if [ "$strict" = true ] && [ "$resolve" = true ]; then
    ok "$default's rules make GitHub check again, at the merge, that it's up to date and has no open thread"
  fi
  [ "$strict" = true ] ||
    no "$default's rules don't require branches to be up to date before merging: the owner turns that on (stacks.md step 4)"
  [ "$resolve" = true ] ||
    no "$default's rules don't require conversation resolution before merging: the owner turns that on (stacks.md step 4)"
  gh api graphql -f query="$rollup_query" -F owner="$owner" -F name="$name" -F pr="$pr" \
    --jq "$rollup_jq" > "$tmp/rollup" || return 1
  # The latest run of each required check on the head.
  awk -F '\t' -v head="$head0" '
    FILENAME == ARGV[1] { req[$0] = 1; next }
    $1 != head { next }
    { if ($6 == "true") req[$3] = 1
      if (!($3 in id) || $2 + 0 >= id[$3] + 0) { id[$3] = $2; st[$3] = $4; co[$3] = $5 } }
    END { for (n in req) {
            if (!(n in st)) print "missing\t" n
            else if (st[n] != "COMPLETED") print "running\t" n
            else if (co[n] ~ /^(SUCCESS|SKIPPED|NEUTRAL)$/) print "passed\t" n
            else print "failed\t" n " (" tolower(co[n]) ")" } }' \
    "$tmp/required" "$tmp/rollup" | LC_ALL=C sort > "$tmp/checks"
  local kind list
  for kind in passed failed running missing; do
    list=$(awk -F '\t' -v k="$kind" '$1 == k { print $2 }' "$tmp/checks" | commas)
    [ -n "$list" ] || continue
    case "$kind" in
      passed) ok "required checks passed: $list" ;;
      failed) no "required checks failed: $list. Re-run a flake, or fix it (review.md §4)" ;;
      running) waiting "required checks running: $list" ;;
      missing)
        local held
        held=$(gh run list --repo "$repo" --commit "$head0" --json databaseId,event,conclusion \
          --jq '[.[] | select(.event == "pull_request" and .conclusion == "action_required")
                 | .databaseId][0] // empty') || return 1
        if [ -n "$held" ]; then
          no "GitHub holds the PR's CI run: start it with gh run rerun $held --repo $repo (review.md §4)"
        else
          waiting "required checks not reported yet: $list"
        fi
        ;;
    esac
  done
  [ -s "$tmp/checks" ] || no "found no required checks for $default"

  local run short=${tip:0:7}
  run=$(gh run list --repo "$repo" --branch "$default" --workflow ci.yml --event push --commit "$tip" \
    --limit 1 --json databaseId,status,conclusion,url --jq '.[] | [.status,
      (if (.conclusion // "") == "" then "-" else .conclusion end),
      (.databaseId | tostring), .url] | join(" ")') || return 1
  read -r ci_status ci_conclusion ci_id ci_url <<< "${run:-none - - -}"
  if [ "$ci_status" = none ]; then
    waiting "no CI run of $default's tip, $short, yet"
  elif [ "$ci_status" != completed ]; then
    waiting "$default's CI run on $short: $ci_url"
  elif [ "$ci_conclusion" = success ]; then
    ok "$default's CI run passed, on its tip $short"
  elif [ "$ci_conclusion" = action_required ]; then
    no "GitHub holds $default's CI run on $short: start it with gh run rerun $ci_id --repo $repo"
  else
    no "$default's CI run on $short ended $ci_conclusion: $ci_url. Re-run a known flake (review.md §4) with gh run rerun $ci_id --failed --repo $repo; tell the owner of anything else"
  fi
}

# Copilot's reviews before watch_pr.sh runs, which it judges: their keys.
copilot_reviews() {
  gh api --paginate "repos/$repo/pulls/$pr/reviews?per_page=100" \
    --jq "$reviewer_jq"' .[] | select(reviewer) | "review-\(.id)"' \
    > "$tmp/judged"
}

try3 read_pr || gh_down
head0=$head base0=$base
default_branch() { default=$(gh api "repos/$repo" --jq .default_branch); }
try3 default_branch || gh_down
for ref in "$default" "$head_ref"; do
  [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "Bad branch name: $ref" >&2; exit 1; }
done
echo "Landing $repo#$pr, $head_ref into $base, at ${head0:0:7}."

# Retargets the open PRs still based on the landed PR's branch to its base, before anyone deletes
# that branch, which would close them (stacks.md step 6). GitHub may already have done it, and a PR
# that someone retargeted elsewhere since open_above read it stays as it is.
retarget() {
  local m now
  for m in "$@"; do
    now=$(gh api "repos/$repo/pulls/$m" --jq '"\(.state) \(.base.ref)"') || now=""
    case "$now" in
      "open $base") echo "#$m already targets $base." ;;
      "open $head_ref")
        gh api -X PATCH "repos/$repo/pulls/$m" -f base="$base" --jq '"Retargeted #\(.number) to \(.base.ref)."' \
          || echo "warning: could not retarget #$m to $base: do it with gh pr edit $m --base $base" >&2
        ;;
      open\ *) echo "#$m targets ${now#open } now, not $head_ref: left as it is." ;;
      closed\ *)
        echo "warning: #$m is closed now. If deleting $head_ref closed it, restore that branch, reopen #$m and retarget it (stacks.md step 6)." >&2
        ;;
      *) echo "warning: could not read #$m: if it's open, gh pr edit $m --base $base" >&2 ;;
    esac
  done
}
open_above() {
  gh api "repos/$repo/pulls?state=open&base=$head_ref&per_page=100" --jq '.[].number' > "$tmp/above"
}

# What can change until the merge, read after watch_pr.sh: the open PRs based on this one's branch,
# the feedback, and the PR itself, last. Only the merge comes after.
last_look() { open_above && feedback && read_pr; }

# Adds to the report what last_look read: the feedback that came since this started, and the PR.
pr_lines() {
  # watch_pr.sh judges Copilot's reviews, but only those that came before it ran.
  awk -F '\t' 'FILENAME == ARGV[1] { seen[$0] = 1; next }
               !($1 in seen) && $4 != "copilot"' "$tmp/seen" "$tmp/feedback" \
    > "$tmp/new"
  awk -F '\t' 'FILENAME == ARGV[1] { judged[$0] = 1; next }
               !($1 in judged) && $4 == "copilot"' "$tmp/judged" "$tmp/feedback" \
    >> "$tmp/new"
  local who url
  while IFS=$'\t' read -r _ who url _; do
    no "new since this started, by $who: $url. Answer it (review.md §2), then run this again"
  done < "$tmp/new"

  [ "$state" = open ] || no "the PR is $state"
  [ "$draft" != true ] || no "the PR is a draft"
  [ "$head_repo" = "$repo" ] || no "the head branch is in ${head_repo:-a deleted fork}, not $repo"
  case ",$labels," in
    *",$label,"*) no "labelled $label: the owner lands it" ;;
  esac
  if [ "$base" = "$default" ]; then
    ok "the base is $default"
  else
    no "the base is $base: only PRs into $default land, after the PR below (stacks.md step 5)"
  fi
  # The gate read the PR's retargets before watch_pr.sh ran, so a retarget since stops it.
  [ "$base" = "$base0" ] || no "the base changed from $base0 while this ran: run this again"
  case "$mstate" in
    dirty) no "it conflicts with $default" ;;
    unknown) waiting "GitHub is still working out whether it can merge" ;;
  esac

  # watch_pr.sh reads the head itself, so its answer counts only if the head is still the one that
  # the gate checked and the merge is pinned to.
  if [ "$head" != "$head0" ]; then
    no "the head moved to ${head:0:7}: run watch_pr.sh $pr, then this again"
    return 0
  fi
  case "$watch_exit" in
    0) ok "watch_pr.sh exits 0: Copilot reviewed the head, and nothing needs an answer" ;;
    2) no "watch_pr.sh exits 2: feedback needs an answer (above, review.md §2)" ;;
    3) no "watch_pr.sh exits 3: no Copilot review of the head: gh pr edit $pr --add-reviewer @copilot" ;;
    5) no "watch_pr.sh exits 5: a check failed (above, review.md §4)" ;;
  esac
}

if [ "$merged" = true ]; then
  echo "Exit 0: $repo#$pr is already merged, as ${merge_sha:0:7}."
  if [ -z "$check" ] && try3 open_above && [ -s "$tmp/above" ]; then
    # shellcheck disable=SC2046 # PR numbers, one per line
    retarget $(cat "$tmp/above")
  fi
  exit 0
fi

# The feedback so far. On each pass, watch_pr.sh checks that Copilot's review of the head and each
# person's post, however old, have an answer (docs/agents/review.md §2 item 4), so a restart
# clears no hold. Anything else that comes while this runs stops it, to be answered first.
try3 feedback || gh_down
cut -f1 "$tmp/feedback" | LC_ALL=C sort -u > "$tmp/seen"

deadline=$(($(date +%s) + minutes * 60))
first=1
while :; do
  try3 gate || gh_down
  try3 copilot_reviews || gh_down
  # Copilot's review of the head, and anything that still needs an answer (docs/agents/review.md
  # §3), on each pass: a review or a failed check can come while this waits.
  watch_exit=0
  "$here/watch_pr.sh" "$pr" --minutes 0 --repo "$repo" > "$tmp/watch" 2>&1 || watch_exit=$?
  if [ -n "$first" ] || [ "$watch_exit" -ne 0 ]; then sed 's/^/  | /' "$tmp/watch"; fi
  case "$watch_exit" in
    0 | 2 | 3 | 5) ;;
    *) echo "Exit 1: watch_pr.sh exited $watch_exit (above)." >&2; exit 1 ;;
  esac
  # Last, so that a label, a retarget or a comment that comes while the gate and watch_pr.sh run
  # still stops it.
  try3 last_look || gh_down
  [ "$merged" != true ] || break
  pr_lines
  if [ -n "$first" ]; then cat "$tmp/report"; fi
  now=$(date +%s)
  if [ "$fails" -gt 0 ] || [ "$waits" -eq 0 ] || [ -n "$check" ] || [ "$now" -ge "$deadline" ]; then
    break
  fi
  echo "$(date -u +%H:%M:%S) UTC: waiting: $(sed -n 's/^  wait  //p' "$tmp/report" | commas)"
  first=""
  nap=$interval
  [ $((now + nap)) -le "$deadline" ] || nap=$((deadline - now))
  sleep "$nap"
done
[ -n "$first" ] || [ "$merged" = true ] || cat "$tmp/report"

if [ "$merged" = true ]; then
  echo "Exit 0: $repo#$pr merged while this waited, as ${merge_sha:0:7}. Someone else landed it."
  exit 0
elif [ "$fails" -gt 0 ]; then
  echo "Exit 2: the gate fails (each \"no\" above). Fix it, or label the PR $label and say why in a comment."
  exit 2
elif [ -n "$check" ]; then
  if [ "$waits" -gt 0 ]; then
    echo "Exit 0: the gate passes, once what it waits for is done."
  else
    echo "Exit 0: the gate passes."
  fi
  exit 0
elif [ "$waits" -gt 0 ]; then
  echo "Exit 3: still waiting after $minutes min. Run this again."
  exit 3
fi

if ! gh pr merge "$pr" --repo "$repo" --squash --match-head-commit "$head0" > "$tmp/merge" 2>&1; then
  cat "$tmp/merge"
  try3 read_pr || gh_down
  if [ "$merged" != true ]; then
    echo "Exit 2: GitHub refused the merge (above)."
    exit 2
  fi
fi
try3 read_pr || gh_down
[ "$merged" = true ] || { cat "$tmp/merge"; echo "Exit 2: GitHub didn't merge it (above)."; exit 2; }
echo "Merged $repo#$pr as ${merge_sha:0:7}."
if [ -s "$tmp/above" ]; then
  # shellcheck disable=SC2046 # PR numbers, one per line
  retarget $(cat "$tmp/above")
  echo "Next: update $(sed 's/^/#/' "$tmp/above" | commas) (docs/agents/stacks.md step 5)."
fi
echo "Exit 0: landed."
