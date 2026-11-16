#!/usr/bin/env python3
"""Runs tools/agent/land_pr.sh and watch_pr.sh against the fake gh, date and sleep in bin/, in the
scenarios below, and checks each one's exit code and output. Needs python3, bash and jq.

Usage: python3 tools/agent/test/scenarios.py [-v] [--jobs N] [--scripts DIR] [scenario ...]

Exit codes: 0 every scenario passed; 1 some failed, each printed with the script's output; 2 a usage
error, an unknown scenario, no jq, or a fake in bin/ that isn't executable. --scripts runs the
scripts in DIR instead: for a negative case, run them on an executable copy with the change undone,
and the scenarios that test it must fail."""
import argparse
import concurrent.futures
import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
# The fake date's time when a scenario starts. The fake sleep advances it.
CLOCK = 1794700000
H = "532908a" + "1" * 33
H2 = "9999999" + "2" * 33
MAIN = "81f22e3" + "0" * 33
OLD = "7777777" + "3" * 33
REQUIRED = ["lint", "test", "export-web", "export-android (Android APK)", "export-android (Android AAB)"]


def check_run(i, name, status="COMPLETED", conclusion="SUCCESS", required=True):
    return {"__typename": "CheckRun", "databaseId": i, "name": name, "status": status,
            "conclusion": conclusion, "isRequired": required}


def rollup(nodes, oid=H):
    return {"data": {"repository": {"pullRequest": {"commits": {"nodes": [
        {"commit": {"oid": oid, "statusCheckRollup": {"contexts": {"nodes": nodes}}}}]}}}}}


def threads(nodes):
    return {"data": {"repository": {"pullRequest": {"reviewThreads": {
        "pageInfo": {"hasNextPage": False, "endCursor": None}, "nodes": nodes}}}}}


def thread(resolved, who="Copilot"):
    return {"id": "PRRT_x1", "isResolved": resolved, "path": "disasters/director.gd", "line": 3,
            "comments": {"nodes": [{"author": {"login": who}, "url": "https://example/c1"}]}}


def timeline(nodes):
    return {"data": {"repository": {"pullRequest": {"timelineItems": {
        "pageInfo": {"hasNextPage": False, "endCursor": None}, "nodes": nodes}}}}}


def retargeted(previous, current="main"):
    return {"previousRefName": previous, "currentRefName": current}


def auto_retargeted(old, new="main"):
    return {"oldBase": old, "newBase": new}


def main_run(i, status="completed", conclusion="success", sha=MAIN, event="push"):
    """A CI run on main, newest first in runs_main."""
    return {"databaseId": i, "status": status, "conclusion": conclusion, "headSha": sha, "headBranch": "main",
            "event": event, "url": f"https://example/runs/{i}"}


def pr_run(i, event="pull_request", conclusion="success"):
    """A CI run on the PR's head, newest first in runs_commit."""
    return {"databaseId": i, "event": event, "conclusion": conclusion, "headSha": H}


CLEAN = "### 🟢 Approval recommended The changes have no active review issues. **No open issues**"
BASE = {
    "pr": {"number": 81, "state": "open", "merged": False, "draft": False, "base": {"ref": "main"},
           "head": {"ref": "pl/1-picks", "sha": H, "repo": {"full_name": "pompomon/roadgame"}},
           "mergeable_state": "blocked", "labels": [], "merge_commit_sha": "abc" + "0" * 37},
    "plans": [{"number": 80, "merged_at": "2026-11-14T10:00:00Z"}],
    "bases": timeline([]),
    "below": [{"number": 79, "merged_at": "2026-11-14T12:00:00Z"}],
    "above": [{"number": 82}],
    "threads": threads([thread(True)]),
    "compare": {"behind_by": 0, "ahead_by": 3, "files": [
        {"filename": "disasters/director.gd"}, {"filename": "POOLS_PLAN.md"},
        {"filename": "tests/unit/test_director.gd"}]},
    "rules": [{"type": "pull_request", "parameters": {"required_review_thread_resolution": True}},
              {"type": "required_status_checks", "parameters": {
                  "strict_required_status_checks_policy": True,
                  "required_status_checks": [{"context": c} for c in REQUIRED]}}],
    "rollup": rollup([check_run(10 + i, c) for i, c in enumerate(REQUIRED)]
                     + [check_run(30, "copilot-pull-request-reviewer", required=False)]),
    "runs_commit": [pr_run(300)],
    "runs_main": [main_run(200)],
    "mainref": {"ref": "refs/heads/main", "object": {"sha": MAIN, "type": "commit"}},
    "inline_comments": [],
    "issue_comments": [],
    "reviews": [{"id": 1, "state": "COMMENTED", "body": CLEAN, "submitted_at": "2026-11-15T05:00:00Z",
                 "user": {"login": "copilot-pull-request-reviewer[bot]", "type": "Bot"},
                 "html_url": "https://example/r1", "commit_id": H}],
    "checkruns": {"check_runs": [{"id": 10 + i, "status": "completed", "conclusion": "success",
                                  "name": c} for i, c in enumerate(REQUIRED)]},
}


def with_(path, value):
    """A change to the fixtures: sets the value at the path."""
    def f(s):
        node = s
        for k in path[:-1]:
            node = node[k]
        node[path[-1]] = copy.deepcopy(value)
    return f


def extra(name, value):
    """A change to the fixtures: adds one. NAME@k replaces NAME from phase k on (bin/gh)."""
    def f(s):
        s[name] = copy.deepcopy(value)
    return f


def pr_with(**changes):
    """A pr fixture: the scenario's PR with these fields changed."""
    return ["PR", changes]


def files_(files):
    """The files of the PR's diff with main."""
    return with_(["compare", "files"], files)


UNCLEAN = "### 🟡 Changes recommended **1 open issue**"
# The PR's URL, to which answers link, and a link to the head's review, BASE's review 1.
P = "https://github.com/pompomon/roadgame/pull/81"
LINK = f"{P}#pullrequestreview-1"


def user(who, kind=None):
    """GitHub's user object: Copilot and logins ending [bot] are bots, unless kind says otherwise."""
    return {"login": who, "type": kind or ("Bot" if who == "Copilot" or who.endswith("[bot]") else "User")}


def comment(body, i=7, who="pompomon", assoc="OWNER", app="copilot-swe-agent", at="2026-11-15T05:10:00Z", kind=None):
    """A PR comment, after the head's review: by default an agent's, posted with gh as the owner."""
    c = {"id": i, "created_at": at, "user": user(who, kind), "body": body, "html_url": f"https://example/c{i}"}
    if assoc is not None:
        c["author_association"] = assoc
    if app is not None:
        c["performed_via_github_app"] = {"slug": app}
    return c


def person(body, i=7, who="pompomon", assoc="OWNER", at="2026-11-15T05:10:00Z"):
    """A person's PR comment, not made via an app: the owner's, unless who and assoc say otherwise."""
    return comment(body, i, who, assoc, None, at)


def review(i, state, body, who="pompomon", assoc="OWNER", kind=None, at="2026-11-15T05:05:00Z"):
    """A person's review of the head, after Copilot's."""
    def f(s):
        s["reviews"].append({"id": i, "state": state, "body": body, "submitted_at": at,
                             "user": user(who, kind), "author_association": assoc,
                             "html_url": f"https://example/r{i}", "commit_id": H})
    return f


# Anyone can pick a login that starts like the reviewer's bot's.
LOOKALIKE = "copilot-pull-request-reviewer-x"


def lookalike(state="COMMENTED", body=CLEAN, i=2):
    """A person's review of the head, by a login that starts like Copilot's reviewer's."""
    return {"id": i, "state": state, "body": body, "submitted_at": "2026-11-15T05:10:00Z",
            "user": user(LOOKALIKE), "author_association": "NONE", "html_url": f"https://example/r{i}",
            "commit_id": H}


def answer(what, link, i=8, **kw):
    """A post that answers what the link points to."""
    return comment(f"Re [{what}]({link}): done.", i, **kw)


def reply(body, i=8, who="pompomon", assoc="OWNER"):
    """A reply in a review thread, after the head's review: by default one posted with gh as the owner."""
    return {"id": i, "created_at": "2026-11-15T05:10:00Z", "user": user(who), "author_association": assoc,
            "path": "a.gd", "line": 1, "body": body, "in_reply_to_id": 5, "html_url": f"https://example/i{i}"}


# watch_pr.sh's first read, of the PR's state and head; land_pr.sh's open_above, after watch_pr.sh.
WATCH_READ = "\\(.state) \\(.merged)"
ABOVE_READ = "state=open&base="


def rollup_nodes(nodes):
    return with_(["rollup"], rollup(nodes))


ok_nodes = [check_run(10 + i, c) for i, c in enumerate(REQUIRED)]
running_nodes = [check_run(10 + i, c, "IN_PROGRESS", None) for i, c in enumerate(REQUIRED)]

# name, args, changes, exit code, what the output must contain (or calls.log, after call:), merged?,
# the PRs retargeted to main
LAND = [
    ("pass-merge", [], [], 0, ["Merged pompomon/roadgame#81 as f00d000", "Retargeted #82 to main",
                               "Next: update #82", "Exit 0: landed.",
                               "ok    main's rules make GitHub check again, at the merge",
                               "ok    main's CI run passed, on its tip 81f22e3",
                               "ok    its diff with main changes none of the owner's paths, in 3 file(s)",
                               f"call:compare/{MAIN}...{H} ", f"call:--event push --commit {MAIN} "],
     True, [82]),
    ("check-only", ["--check"], [], 0, ["Exit 0: the gate passes."], False, []),
    ("needs-owner", [], [with_(["pr", "labels"], [{"name": "needs-owner"}])], 2,
     ["no    labelled needs-owner"], False, []),
    ("draft", [], [with_(["pr", "draft"], True)], 2, ["no    the PR is a draft"], False, []),
    ("fork", [], [with_(["pr", "head", "repo"], {"full_name": "someone/roadgame"})], 2,
     ["no    the head branch is in someone/roadgame"], False, []),
    ("fork-deleted", [], [with_(["pr", "head", "repo"], None)], 2,
     ["no    the head branch is in a deleted fork"], False, []),
    ("base-not-main", [], [with_(["pr", "base", "ref"], "pl/0-base")], 2,
     ["no    the base is pl/0-base"], False, []),
    ("plan-unmerged", [], [with_(["plans"], [])], 2,
     ["no    the plan isn't approved: no PR from pl/plan"], False, []),
    ("plan-closed-unmerged", [], [with_(["plans"], [{"number": 79, "merged_at": None}])], 2,
     ["no    the plan isn't approved"], False, []),
    ("plan-pr", [], [with_(["pr", "head", "ref"], "pl/plan")], 2,
     ["no    pl/plan isn't a plan's PR"], False, []),
    ("docs-branch", [], [with_(["pr", "head", "ref"], "docs/agents-land")], 2,
     ["no    docs/agents-land isn't a plan's PR"], False, []),
    ("owner-path", [], [files_([{"filename": "AGENTS.md"}, {"filename": "road/x.gd"}])], 2,
     ["no    its diff with main changes paths that the owner lands: AGENTS.md"], False, []),
    ("owner-path-renamed-away", [], [files_([
        {"filename": "tools/x.sh", "previous_filename": "tools/agent/x.sh"}])], 2,
     ["no    its diff with main changes paths that the owner lands: tools/agent/x.sh"], False, []),
    ("owner-path-summary", [], [files_([{"filename": "docs/README.md"}])], 2,
     ["no    its diff with main changes paths that the owner lands: docs/README.md"], False, []),
    ("not-owner-lookalike", ["--check"], [files_([
        {"filename": "docs/agents.md"}, {"filename": "tools/cinematic/a.gd"},
        {"filename": "docs/M2.md"}])], 0, ["ok    its diff with main changes none of the owner's paths, in 3 file(s)"],
     False, []),
    ("too-many-files", [], [files_([{"filename": f"road/f{i}.gd"} for i in range(300)])], 2,
     ["no    its diff with main has 300 files or more, more than GitHub lists: the owner lands it"],
     False, []),
    # Retargeted to main before the PR below it landed.
    ("retargeted-from-open", [], [with_(["bases"], timeline([retargeted("pl/0-base")])),
                                  with_(["below"], [])], 2,
     ["no    it was based on pl/0-base, and no PR from it has merged into main: PRs land bottom up",
      "call:pulls?state=closed&base=main&head=pompomon:pl/0-base&"], False, []),
    ("retargeted-from-unmerged", [], [with_(["bases"], timeline([retargeted("pl/0-base")])),
                                      with_(["below"], [{"number": 79, "merged_at": None}])], 2,
     ["no    it was based on pl/0-base, and no PR from it has merged into main"], False, []),
    ("auto-retargeted", [], [with_(["bases"], timeline([auto_retargeted("pl/0-base")]))], 0,
     ["ok    it was based on pl/0-base, which has landed (#79)", "Exit 0: landed."], True, [82]),
    ("retargeted-odd-name", [], [with_(["bases"], timeline([retargeted("pl/0&base")]))], 2,
     ["no    it was based on pl/0&base, an odd branch name: the owner lands it"], False, []),
    ("open-thread", [], [with_(["threads"], threads([thread(True), thread(False, "pompomon")]))], 2,
     ["no    open thread by pompomon at disasters/director.gd:3: https://example/c1 (id PRRT_x1)"],
     False, []),
    ("behind", [], [with_(["compare", "behind_by"], 2)], 2, ["no    2 commits behind main"], False, []),
    ("dirty", [], [with_(["pr", "mergeable_state"], "dirty")], 2, ["no    it conflicts with main"],
     False, []),
    ("unknown-mergeable", ["--minutes", "0"], [with_(["pr", "mergeable_state"], "unknown")], 3,
     ["wait  GitHub is still working out", "Exit 3: still waiting after 0 min"], False, []),
    ("latest-run-passed", ["--check"], [rollup_nodes(
        [check_run(5, "lint", conclusion="FAILURE")] + ok_nodes)], 0, ["Exit 0: the gate passes."],
     False, []),
    ("latest-run-failed", [], [rollup_nodes(
        ok_nodes + [check_run(50, "lint", conclusion="FAILURE")])], 2,
     ["no    required checks failed: lint (failure)"], False, []),
    ("required-from-rollup", ["--check"], [
        with_(["rules", 1, "parameters", "required_status_checks"], []),
        rollup_nodes([check_run(10, "lint"), check_run(11, "extra", required=False, conclusion="FAILURE")])], 0,
     ["ok    required checks passed: lint"], False, []),
    ("no-required", [], [with_(["rules", 1, "parameters", "required_status_checks"], []),
                         rollup_nodes([check_run(10, "lint", required=False)])],
     2, ["no    found no required checks for main"], False, []),
    ("other-commit-checks", ["--minutes", "0"], [with_(["rollup"], rollup(ok_nodes, oid=H2))], 3,
     ["wait  required checks not reported yet"], False, []),
    ("held-pr-run", [], [rollup_nodes([check_run(30, "copilot-pull-request-reviewer", required=False)]),
                         with_(["runs_commit"], [pr_run(301, "workflow_dispatch"),
                                                 pr_run(300, conclusion="action_required")])], 2,
     ["no    GitHub holds the PR's CI run: start it with gh run rerun 300 --repo pompomon/roadgame"],
     False, []),
    ("checks-running", ["--minutes", "0"], [rollup_nodes(running_nodes)], 3,
     ["wait  required checks running: export-android (Android AAB)", "Exit 3"], False, []),
    ("checks-running-check", ["--check"], [rollup_nodes(running_nodes)], 0,
     ["Exit 0: the gate passes, once what it waits for is done."], False, []),
    ("main-ci-failed", [], [with_(["runs_main", 0, "conclusion"], "failure")], 2,
     ["Re-run a known flake (review.md §4) with gh run rerun 200 --failed --repo pompomon/roadgame"],
     False, []),
    ("main-ci-held", [], [with_(["runs_main", 0, "conclusion"], "action_required")], 2,
     ["no    GitHub holds main's CI run on 81f22e3: start it with gh run rerun 200"], False, []),
    ("main-ci-running", ["--minutes", "0"], [with_(["runs_main", 0, "status"], "in_progress"),
                                             with_(["runs_main", 0, "conclusion"], "")], 3,
     ["wait  main's CI run on 81f22e3"], False, []),
    ("main-ci-none", ["--minutes", "0"], [with_(["runs_main"], [])], 3,
     ["wait  no CI run of main's tip, 81f22e3, yet"], False, []),
    ("main-ci-old-sha", ["--minutes", "0"], [with_(["runs_main", 0, "headSha"], OLD)], 3,
     ["wait  no CI run of main's tip, 81f22e3, yet", "Exit 3"], False, []),
    ("main-ci-tip-of-two", [], [with_(["runs_main"], [main_run(201, conclusion="failure", sha=OLD), main_run(200)])],
     0, ["ok    main's CI run passed, on its tip 81f22e3", "Exit 0: landed."], True, [82]),
    # A run by hand on main's tip, newer than its push run, isn't the one that counts.
    ("main-ci-dispatch-run", ["--minutes", "0"], [with_(["runs_main"], [
        main_run(202, "in_progress", "", event="workflow_dispatch"), main_run(200)])],
     0, ["ok    main's CI run passed, on its tip 81f22e3", "Exit 0: landed."], True, [82]),
    ("rules-not-strict", [], [with_(["rules", 1, "parameters", "strict_required_status_checks_policy"],
                                    False)], 2,
     ["no    main's rules don't require branches to be up to date before merging"], False, []),
    ("rules-no-thread-resolution", [], [with_(["rules", 0, "parameters"], {})], 2,
     ["no    main's rules don't require conversation resolution before merging"], False, []),
    ("rules-none", [], [with_(["rules"], [])], 2,
     ["no    main's rules don't require branches", "no    main's rules don't require conversation"],
     False, []),
    ("interval-too-short", ["--interval", "5"], [], 1, ["--interval must be at least 10 seconds"],
     False, []),
    ("no-review", [], [with_(["reviews"], [])], 2,
     ["no    watch_pr.sh exits 3: no Copilot review of the head: gh pr edit 81 --add-reviewer @copilot"],
     False, []),
    ("review-of-old-head", [], [with_(["reviews", 0, "commit_id"], H2)], 2, ["watch_pr.sh exits 3"],
     False, []),
    ("unanswered-review", [], [with_(["reviews", 0, "body"], UNCLEAN)],
     2, ["no    watch_pr.sh exits 2"], False, []),
    # An unclean review of the head is answered only by a review or PR comment that starts with a
    # link to it (review.md §2).
    ("unrelated-comment-after-review", [], [with_(["reviews", 0, "body"], UNCLEAN),
                                            extra("issue_comments", [comment("Re-running CI.")])], 2,
     ["It isn't clean, and no review or PR comment starts with a link to it", "no    watch_pr.sh exits 2"], False, []),
    ("linked-answer", [], [with_(["reviews", 0, "body"], UNCLEAN),
                           extra("issue_comments", [comment(f"Re [Copilot's review of 532908a]({LINK}): declined.")])],
     0, ["ok    watch_pr.sh exits 0", "Exit 0: landed."], True, [82]),
    # A writer's thread reply that starts with a link to the review answers its thread, now
    # resolved, not the review's findings that have no thread.
    ("linked-thread-reply", [], [with_(["reviews", 0, "body"], UNCLEAN), extra("inline_comments", [
        reply(f"Re [Copilot's review of 532908a]({LINK}): declined.")])],
     2, ["It isn't clean, and no review or PR comment starts with a link to it", "no    watch_pr.sh exits 2"],
     False, []),
    # Copilot's reviewer is known by its bot's exact login: a lookalike's clean review neither
    # stands for Copilot's, nor passes as one that watch_pr.sh judged when it comes while this waits.
    ("lookalike-clean-review", [], [with_(["reviews", 0, "body"], UNCLEAN),
                                    lambda s: s["reviews"].append(lookalike())], 2,
     ["It isn't clean, and no review or PR comment starts with a link to it", "no    watch_pr.sh exits 2"], False, []),
    ("lookalike-approval-while-waiting", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("rollup@1", rollup(ok_nodes)),
        extra("reviews@2", BASE["reviews"] + [lookalike("APPROVED", "")])], 2,
     ["waiting: required checks running",
      f"no    new since this started, by {LOOKALIKE}: https://example/r2"], False, []),
    ("watch-check-failed", [], [with_(["checkruns", "check_runs", 0, "conclusion"], "failure")], 2,
     ["no    watch_pr.sh exits 5"], False, []),
    ("already-merged", [], [extra("merged", None)], 0,
     ["Exit 0: pompomon/roadgame#81 is already merged, as f00d000", "Retargeted #82 to main"], False, [82]),
    ("already-merged-check", ["--check"], [extra("merged", None)], 0, ["already merged"], False, []),
    ("merge-refused", [], [extra("merge_fail", {})], 2,
     ["Required status check", "Exit 2: GitHub refused the merge"], True, []),
    ("no-pr-above", [], [with_(["above"], [])], 0, ["Exit 0: landed."], True, []),
    ("two-prs-above", [], [with_(["above"], [{"number": 82}, {"number": 83}])], 0,
     ["Retargeted #82 to main.", "Retargeted #83 to main.", "Next: update #82, #83 (", "Exit 0: landed."],
     True, [82, 83]),
    ("above-one-retargeted-by-github", [], [with_(["above"], [{"number": 82}, {"number": 83}]), extra(
        "above_pr", {"number": 82, "state": "open", "base": {"ref": "main"}})], 0,
     ["#82 already targets main.", "Retargeted #83 to main.", "Exit 0: landed."], True, [83]),
    ("above-retargeted-by-github", [], [extra("above_pr", {"number": 82, "state": "open",
                                                           "base": {"ref": "main"}})], 0,
     ["#82 already targets main.", "Exit 0: landed."], True, []),
    # Retargeted elsewhere after open_above read it: left as it is.
    ("above-retargeted-elsewhere", [], [extra("above_pr", {"number": 82, "state": "open",
                                                           "base": {"ref": "pl/other"}})], 0,
     ["#82 targets pl/other now, not pl/1-picks: left as it is.", "Exit 0: landed."], True, []),
    ("above-closed", [], [extra("above_pr", {"number": 82, "state": "closed",
                                             "base": {"ref": "pl/1-picks"}})], 0,
     ["warning: #82 is closed now. If deleting pl/1-picks closed it", "Exit 0: landed."], True, []),
    ("slow-checks-pass", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("rollup@1", rollup(ok_nodes))], 0,
     ["waiting: required checks running", "ok    required checks passed", "Exit 0: landed."], True, [82]),
    ("slow-head-moved", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("pr@2", "MOVED")], 2,
     ["no    the head moved to 9999999"], False, []),
    ("slow-merged-meanwhile", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("pr@2", "MERGED")], 0,
     ["merged while this waited, as f00d000"], False, []),
    # A person's post that was there before it started holds it until a PR comment answers it, so a
    # restart clears no hold (docs/agents/review.md §2).
    ("old-comment", [], [extra("issue_comments", [person("Fine?", at="2026-11-15T04:50:00Z")])], 2,
     ["no    watch_pr.sh exits 2", "From people, and no review or PR comment starts with a link to it",
      "pompomon: Fine?", "https://example/c7"], False, []),
    ("old-comment-answered", [], [extra("issue_comments", [
        person("Fine?", at="2026-11-15T04:50:00Z"),
        answer("pompomon's comment", f"{P}#issuecomment-7", at="2026-11-15T04:55:00Z")])], 0,
     ["Exit 0: landed."], True, [82]),
    # An agent's note that was there before it started needs no answer, and isn't new.
    ("old-comment-agent-note", [], [extra("issue_comments", [
        comment("**Frames (§5.6)**: all pass.", at="2026-11-15T04:50:00Z")])], 0,
     ["Exit 0: landed."], True, [82]),
    # Feedback while it waits: pass 1 sees phase-1 fixtures, pass 2 phase 2 (one rollup query a pass).
    ("slow-new-comment", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("rollup@1", rollup(ok_nodes)),
        extra("issue_comments@2", [person("Hold on", i=9)])], 2,
     ["waiting: required checks running",
      "no    new since this started, by pompomon: https://example/c9. Answer it"], False, []),
    ("slow-new-inline", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("rollup@1", rollup(ok_nodes)),
        extra("inline_comments@2", [{"id": 8, "created_at": "2026-11-15T05:10:00Z", "user": None,
                                     "path": "a.gd", "line": 1, "body": "Why?",
                                     "html_url": "https://example/i8"}])], 2,
     ["no    new since this started, by ghost: https://example/i8"], False, []),
    ("slow-new-unclean-review", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("rollup@1", rollup(ok_nodes)),
        extra("reviews@2", BASE["reviews"] + [dict(BASE["reviews"][0], id=2, submitted_at="2026-11-15T05:10:00Z",
                                                   body=UNCLEAN)])], 2,
     ["waiting: required checks running", "no    watch_pr.sh exits 2",
      "It isn't clean, and no review or PR comment starts with a link to it"], False, []),
    ("slow-new-clean-review", ["--minutes", "2", "--interval", "10"], [
        rollup_nodes(running_nodes), extra("rollup@1", rollup(ok_nodes)),
        extra("reviews@2", BASE["reviews"] + [dict(BASE["reviews"][0], id=2,
                                                   submitted_at="2026-11-15T05:10:00Z")])], 0,
     ["waiting: required checks running", "Exit 0: landed."], True, [82]),
    # What comes while the gate and watch_pr.sh run (phase 1, from watch_pr.sh's first read, or
    # from the read of the PRs above, after it) still stops it: land_pr.sh reads it last.
    ("label-during-watch", [], [extra("trigger", WATCH_READ),
                                extra("pr@1", pr_with(labels=[{"name": "needs-owner"}]))], 2,
     ["no    labelled needs-owner"], False, []),
    ("retarget-during-watch", [], [extra("trigger", WATCH_READ),
                                   extra("pr@1", pr_with(base={"ref": "pl/0-base"}))], 2,
     ["no    the base is pl/0-base"], False, []),
    # Retargeted to main while it ran: the gate read the retargets before that.
    ("retarget-to-main-during-watch", [], [with_(["pr", "base", "ref"], "pl/0-base"),
                                           extra("trigger", WATCH_READ),
                                           extra("pr@1", pr_with(base={"ref": "main"}))], 2,
     ["ok    the base is main", "no    the base changed from pl/0-base while this ran: run this again"],
     False, []),
    # An agent's note, which watch_pr.sh lets pass: only land_pr.sh's last read stops it.
    ("comment-during-watch", [], [extra("trigger", WATCH_READ), extra("issue_comments@1", [
        comment("Hold on", i=9)])], 2,
     ["no    new since this started, by pompomon: https://example/c9"], False, []),
    ("review-after-watch", [], [extra("trigger", ABOVE_READ), extra("reviews@1", BASE["reviews"] + [
        dict(BASE["reviews"][0], id=2, submitted_at="2026-11-15T05:10:00Z", html_url="https://example/r2",
             body=UNCLEAN)])], 2,
     ["no    new since this started, by copilot-pull-request-reviewer[bot]: https://example/r2"],
     False, []),
    # The wait ends at the deadline, not an --interval later.
    ("sleep-capped", ["--minutes", "1", "--interval", "600"], [rollup_nodes(running_nodes)], 3,
     ["call:sleep 60 ", "Exit 3: still waiting after 1 min"], False, []),
    ("watch-failed", [], [extra("fail_on", WATCH_READ)], 1,
     ["Exit 1: gh failed 3 times in a row.", "Exit 1: watch_pr.sh exited 1 (above)."], False, []),
    # What the host's environment could put before the fake gh, or log a real one in with, the
    # scripts don't get (child_env).
    ("hostile-host-env", [], [extra("hostile", True)], 0, ["Exit 0: landed."], True, [82]),
]


# watch_pr.sh: only the latest run of each check counts, so neither a duplicate run that ci.yml's
# concurrency cancels nor a failed run re-run since fails it (#48–#52).
dup = {"check_runs": [{"id": 10 + i, "status": "completed", "conclusion": "cancelled", "name": c}
                      for i, c in enumerate(REQUIRED)]
       + [{"id": 40 + i, "status": "completed", "conclusion": "success", "name": c}
          for i, c in enumerate(REQUIRED)]}
rerun_pass = {"check_runs": [{"id": 10, "status": "completed", "conclusion": "failure", "name": "test"},
                             {"id": 90, "status": "completed", "conclusion": "success", "name": "test"}]}
rerun_fail = {"check_runs": [{"id": 90, "status": "completed", "conclusion": "failure", "name": "test"},
                             {"id": 10, "status": "completed", "conclusion": "success", "name": "test"}]}
running = {"check_runs": [{"id": 10, "status": "completed", "conclusion": "failure", "name": "test"},
                          {"id": 90, "status": "in_progress", "conclusion": None, "name": "test"}]}
unclean = with_(["reviews", 0, "body"], UNCLEAN)


def checks(runs):
    return [with_(["checkruns"], runs)]


# name, changes, exit code, output must contain. It runs with --minutes 0, as land_pr.sh runs it.
WATCH = [
    ("cancelled-duplicate", checks(dup), 0, "Checks on 532908a: 5 success"),
    ("later-run-passed", checks(rerun_pass), 0, "Checks on 532908a: 1 success"),
    ("later-run-failed", checks(rerun_fail), 5, "Failed checks: test"),
    ("later-run-running", checks(running), 0, "Checks on 532908a: 1 in_progress"),
    # Started late, after an unclean review of the head: only a review or PR comment that starts
    # with a link to it answers it (review.md §2 item 4).
    ("late-unclean-unrelated-comment", [unclean, extra("issue_comments", [comment("Re-running CI.")])], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    ("late-unclean-thread-reply", [unclean, extra("inline_comments", [
        {"id": 8, "created_at": "2026-11-15T05:10:00Z", "user": {"login": "Copilot", "type": "Bot"},
         "path": "a.gd", "line": 1, "body": "Declined: it can't happen.", "in_reply_to_id": 5,
         "html_url": "https://example/i8"}])], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    # Nor does a writer's thread reply that starts with a link to it: that answers its thread.
    ("late-unclean-linked-thread-reply", [unclean, extra("inline_comments", [
        reply(f"Re [Copilot's review of 532908a]({LINK}): declined.")])], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    ("late-unclean-linked", [unclean, extra("issue_comments", [
        comment(f"Re [Copilot's review of 532908a]({LINK}): declined.")])], 0,
     "Exit 0: Copilot reviewed 532908a"),
    # The cloud agent posts as Copilot, via its app: its answer counts, as a writer's does.
    ("late-unclean-agent-linked", [unclean, extra("issue_comments", [
        comment(f"Re [Copilot's review of 532908a]({LINK}): declined.", who="Copilot", assoc="CONTRIBUTOR")])],
     0,
     "Exit 0: Copilot reviewed 532908a"),
    # The link is read from the raw body, not the text cut to 300 characters.
    ("late-unclean-link-after-300", [unclean, extra("issue_comments", [
        comment("Re [Copilot's review of 532908a, " + "which I read again, " * 20 + f"]({LINK}): declined.")])],
     0, "Exit 0: Copilot reviewed 532908a"),
    # A post that only mentions the review, or links it further on, doesn't answer it.
    ("late-unclean-link-in-passing", [unclean, extra("issue_comments", [
        comment(f"Still on [Copilot's review of 532908a]({LINK}): no answer yet.")])], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    # "Re [" with no link after it answers nothing, and breaks nothing.
    ("late-unclean-re-without-link", [unclean, extra("issue_comments", [comment("Re [CI] re-running it.")])], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    ("late-unclean-link-further-on", [unclean, extra("issue_comments", [
        comment(f"Re [the CI run](https://example/runs/1): re-running it.\n\n"
                f"I'm still on [Copilot's review]({LINK}).")])],
     2, "It isn't clean, and no review or PR comment starts with a link to it"),
    # "Re [" that isn't a link to the review answers nothing, even with the link further on.
    ("late-unclean-re-header-unlinked", [unclean, extra("issue_comments", [
        comment(f"Re [CI] re-running the workflow.\n\nStill investigating [this review]({LINK}); no answer yet.")])],
     2, "It isn't clean, and no review or PR comment starts with a link to it"),
    ("late-unclean-re-header-unlinked-same-line", [unclean, extra("issue_comments", [
        comment(f"Re [CI] re-running it; still investigating [this review]({LINK}).")])],
     2, "It isn't clean, and no review or PR comment starts with a link to it"),
    # Nor does a link to it that starts a later line.
    ("late-unclean-link-not-at-start", [unclean, extra("issue_comments", [
        comment(f"Re-running CI.\n\nRe [Copilot's review of 532908a]({LINK}): to follow.")])],
     2, "It isn't clean, and no review or PR comment starts with a link to it"),
    # Blank lines before the link don't matter.
    ("late-unclean-linked-after-blank-line", [unclean, extra("issue_comments", [
        comment(f"\r\n\n  Re [Copilot's review of 532908a]({LINK}): declined.")])], 0,
     "Exit 0: Copilot reviewed 532908a"),
    # Review 12 isn't review 1.
    ("late-unclean-other-review-linked", [unclean, extra("issue_comments", [
        comment("Re [Copilot's review](https://github.com/pompomon/roadgame/pull/81#pullrequestreview-12): fixed.")])],
     2, "It isn't clean, and no review or PR comment starts with a link to it"),
    # Copilot's reviewer doesn't answer itself, even in a later review that links the head's.
    ("late-unclean-reviewer-links", [unclean, lambda s: s["reviews"].append(dict(
        s["reviews"][0], id=2, submitted_at="2026-11-15T05:10:00Z", commit_id=OLD, html_url="https://example/r2",
        body=f"Re [the review of 532908a]({LINK}): one more issue."))], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    # The repository is public: only a post by someone who can write, or by the cloud agent, answers.
    ("late-unclean-stranger-linked", [unclean, extra("issue_comments", [
        comment(f"Re [Copilot's review of 532908a]({LINK}): declined.", who="someone", assoc="NONE", app=None)])],
     2, "It isn't clean, and no review or PR comment starts with a link to it"),
    # A link to PR comment 1 isn't one to review 1.
    ("late-unclean-comment-linked", [unclean, extra("issue_comments", [
        answer("the comment", f"{P}#issuecomment-1")])], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    # A lookalike's clean review isn't Copilot's.
    ("late-unclean-lookalike-clean", [unclean, lambda s: s["reviews"].append(lookalike())], 2,
     "It isn't clean, and no review or PR comment starts with a link to it"),
    # A person's post needs an answer, however old (docs/agents/review.md §2).
    ("person-comment-unanswered", [extra("issue_comments", [person("Please rename it.")])], 2,
     "From people, and no review or PR comment starts with a link to it"),
    ("person-comment-before-head", [extra("issue_comments", [person("Please rename it.", at="2026-11-15T04:00:00Z")])],
     2, "pompomon: Please rename it."),
    ("person-comment-answered", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-7")])], 0,
     "Exit 0: Copilot reviewed 532908a"),
    # A local agent posts as the owner, with no app: its answer, a writer's note, needs none itself.
    ("person-comment-answered-locally", [extra("issue_comments", [
        person("Please rename it."), person(f"Re [pompomon's comment]({P}#issuecomment-7): renamed.", i=8)])],
     0, "Exit 0: Copilot reviewed 532908a"),
    ("person-comment-answered-by-collaborator", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-7", who="helper",
                                            assoc="COLLABORATOR", app=None)])], 0,
     "Exit 0: Copilot reviewed 532908a"),
    ("person-comment-answered-by-cloud-agent", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-7", who="Copilot",
                                            assoc="CONTRIBUTOR")])], 0, "Exit 0: Copilot reviewed 532908a"),
    # Neither a stranger's answer, nor one via the agent's app by anyone but Copilot, counts.
    ("person-comment-answered-by-stranger", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-7", who="someone",
                                            assoc="NONE", app=None)])], 2, "pompomon: Please rename it."),
    ("person-comment-answered-by-stranger-via-app", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-7", who="someone",
                                            assoc="NONE")])], 2, "pompomon: Please rename it."),
    # The cloud agent's automatic reply quotes the comment: that doesn't answer it.
    ("person-comment-quoted-by-cloud-agent", [extra("issue_comments", [
        person("@copilot rename it."), comment("> @copilot rename it.\n\nRenamed in 1234567.", i=8, who="Copilot",
                                               assoc="CONTRIBUTOR")])], 2, "pompomon: @copilot rename it."),
    ("person-comment-other-linked", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-77")])], 2,
     "pompomon: Please rename it."),
    # Review 7 isn't PR comment 7.
    ("person-comment-review-linked", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#pullrequestreview-7")])], 2,
     "pompomon: Please rename it."),
    # A writer's thread reply answers its thread, not a person's PR comment or review.
    ("person-comment-linked-in-thread", [extra("issue_comments", [person("Please rename it.")]), extra(
        "inline_comments", [reply(f"Re [pompomon's comment]({P}#issuecomment-7): renamed.")])], 2,
     "pompomon: Please rename it."),
    ("stranger-comment", [extra("issue_comments", [person("This looks wrong.", who="someone", assoc="NONE")])],
     2, "someone: This looks wrong."),
    ("stranger-note", [extra("issue_comments", [person("Re [x](https://example/x): do this.", who="someone",
                                                       assoc="NONE")])], 2, "someone: Re [x]"),
    # Another app's post needs one too.
    ("other-app-comment", [extra("issue_comments", [comment("Coverage fell.", who="cov[bot]", assoc="NONE",
                                                            app="cov")])], 2, "cov[bot]: Coverage fell."),
    # Agents' notes, by Copilot's apps or starting with a link, need none.
    ("agent-note", [extra("issue_comments", [comment("**Frames (§5.6)**: all pass.")])], 0,
     "Exit 0: Copilot reviewed 532908a"),
    ("cloud-agent-note", [extra("issue_comments", [comment("Done.", who="Copilot", assoc="CONTRIBUTOR")])], 0,
     "Exit 0: Copilot reviewed 532908a"),
    ("reviewer-notice", [extra("issue_comments", [comment("One or more custom setup steps failed.", who="Copilot",
                                                          assoc="NONE", app="copilot-pull-request-reviewer")])],
     0, "Exit 0: Copilot reviewed 532908a"),
    # Only a writer's post via the cloud agent's app, or the cloud agent's own, is an agent's note,
    # and only Copilot's bot posts the reviewer's notices.
    ("stranger-via-agent-app", [extra("issue_comments", [comment("This looks wrong.", who="someone",
                                                                 assoc="NONE")])], 2,
     "someone: This looks wrong."),
    ("user-named-copilot-answer", [extra("issue_comments", [
        person("Please rename it."), answer("pompomon's comment", f"{P}#issuecomment-7", who="Copilot",
                                            assoc="CONTRIBUTOR", kind="User")])], 2,
     "pompomon: Please rename it."),
    ("user-named-copilot-notice", [extra("issue_comments", [comment(
        "One or more custom setup steps failed.", who="Copilot", assoc="NONE", app="copilot-pull-request-reviewer",
        kind="User")])], 2, "Copilot: One or more custom setup steps failed."),
    ("re-note", [extra("issue_comments", [person(
        "Re [E12, §6.4](https://github.com/pompomon/roadgame/blob/pl/plan/PL_PLAN.md#64-checks): all pass.")])],
     0, "Exit 0: Copilot reviewed 532908a"),
    # People's reviews: with a body, or requesting changes.
    ("person-review-unanswered", [review(3, "COMMENTED", "Rename it.")], 2, "pompomon: review of 532908a: Rename it."),
    ("person-review-answered", [review(3, "COMMENTED", "Rename it."), extra("issue_comments", [
        answer("pompomon's review", f"{P}#pullrequestreview-3")])], 0, "Exit 0: Copilot reviewed 532908a"),
    ("person-review-comment-linked", [review(3, "COMMENTED", "Rename it."), extra("issue_comments", [
        answer("pompomon's review", f"{P}#issuecomment-3")])], 2, "pompomon: review of 532908a: Rename it."),
    ("person-review-linked-in-thread", [review(3, "COMMENTED", "Rename it."), extra("inline_comments", [
        reply(f"Re [pompomon's review]({P}#pullrequestreview-3): renamed.")])], 2,
     "pompomon: review of 532908a: Rename it."),
    ("changes-requested-empty", [review(3, "CHANGES_REQUESTED", "")], 2, "review of 532908a (changes_requested)"),
    ("approved-with-body", [review(3, "APPROVED", "Fine, but rename it.")], 2, "(approved): Fine, but rename it."),
    ("approved-empty", [review(3, "APPROVED", "")], 0, "Exit 0: Copilot reviewed 532908a"),
    ("dismissed-review", [review(3, "DISMISSED", "Rename it.")], 0, "Exit 0: Copilot reviewed 532908a"),
    ("person-review-note", [review(3, "COMMENTED", "Re [the plan](https://example/plan): as planned.")], 0,
     "Exit 0: Copilot reviewed 532908a"),
    # Copilot's reviews of earlier commits were answered then; inline comments are threads, which
    # land_pr.sh holds until they're resolved.
    ("reviewer-old-unclean", [lambda s: s["reviews"].insert(0, dict(
        s["reviews"][0], id=2, submitted_at="2026-11-15T04:00:00Z", commit_id=OLD, body=UNCLEAN))], 0,
     "Exit 0: Copilot reviewed 532908a"),
    ("person-inline-comment", [extra("inline_comments", [
        {"id": 8, "created_at": "2026-11-15T05:10:00Z", "user": {"login": "pompomon", "type": "User"},
         "author_association": "OWNER", "path": "a.gd", "line": 1, "body": "Why?",
         "html_url": "https://example/i8"}])], 0,
     "Exit 0: Copilot reviewed 532908a"),
]


def build(tmp, changes):
    """Writes the scenario's fixtures, BASE with its changes, and the fake date's clock to tmp. Returns
    them."""
    s = copy.deepcopy(BASE)
    for c in changes:
        c(s)
    for k, v in s.items():
        if v == "MOVED":
            v = copy.deepcopy(s["pr"])
            v["head"]["sha"] = H2
        elif v == "MERGED":
            v = copy.deepcopy(s["pr"])
            v.update(merged=True, state="closed", merge_commit_sha="f00d" + "0" * 36)
        elif isinstance(v, list) and v[:1] == ["PR"]:
            p = copy.deepcopy(s["pr"])
            p.update(v[1])
            v = p
        if k == "merged":
            open(os.path.join(tmp, "merged"), "w").close()
        if k in ("merged", "hostile"):
            continue
        with open(os.path.join(tmp, k + ".json"), "w", encoding="utf-8") as f:
            json.dump(v, f)
    with open(os.path.join(tmp, "clock"), "w") as f:
        f.write(str(CLOCK))
    return s


def read(tmp, name):
    """The file that the fakes wrote, or None."""
    path = os.path.join(tmp, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read()


BIN = os.path.join(HERE, "bin")
# What could run something else for the fakes, or log a real gh in: exported functions, files that
# bash or sh run first, gh's and GitHub's variables. Shell options and CDPATH could change the scripts.
DROP = ("BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS", "CDPATH")
DROP_PREFIXES = ("BASH_FUNC_", "GH_", "GITHUB_")


def child_env(tmp, host):
    """The scripts' environment: the host's, without DROP, with the fakes first on PATH, and a gh
    config without logins."""
    env = {k: v for k, v in host.items() if k not in DROP and not k.startswith(DROP_PREFIXES)}
    env.update(FAKE_DIR=tmp, PATH=BIN + os.pathsep + host.get("PATH", ""),
               GH_CONFIG_DIR=os.path.join(tmp, "gh-config"))
    return env


def hostile(tmp):
    """A host's environment that would run another gh than the fake one, or log a real one in."""
    path = os.path.join(tmp, "hostile.sh")
    with open(path, "w") as f:
        f.write("gh() { echo 'hostile gh, from BASH_ENV' >&2; return 1; }\n")
    return dict(os.environ, BASH_ENV=path, GH_TOKEN="hostile",
                **{"BASH_FUNC_gh%%": "() {  echo 'hostile gh, exported' >&2; return 1\n}"})


def run(script, args, tmp, s):
    """Runs the script with the fakes first on PATH: its exit code and output."""
    env = child_env(tmp, hostile(tmp) if "hostile" in s else os.environ)
    p = subprocess.run([script, *args], cwd=tmp, env=env, capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout + p.stderr


def land(case, scripts):
    name, args, changes, code, wants, want_merged, want_retargeted = case
    with tempfile.TemporaryDirectory() as tmp:
        s = build(tmp, changes)
        rc, out = run(os.path.join(scripts, "land_pr.sh"), ["81", *args], tmp, s)
        calls = read(tmp, "calls.log") or ""
        merge_args = read(tmp, "merge_args")
        retargets = read(tmp, "retargeted") or ""
    problems = [] if rc == code else [f"exit {rc}, want {code}"]
    for want in wants:
        if want.startswith("call:"):
            if want[5:] not in calls:
                problems.append(f"no call: {want[5:]}")
        elif want not in out:
            problems.append(f"missing: {want}")
    if (merge_args is not None) != want_merged:
        problems.append(f"merged: {merge_args is not None}, want {want_merged}")
    elif merge_args is not None and merge_args.split() != [
            "merge", "81", "--repo", "pompomon/roadgame", "--squash", "--match-head-commit", H]:
        problems.append("merge args: " + merge_args.strip())
    want_retargets = "".join(f"{n} main\n" for n in want_retargeted)
    if retargets != want_retargets:
        got, expected = (", ".join(t.splitlines()) or "none" for t in (retargets, want_retargets))
        problems.append(f"retargeted: {got}, want {expected}")
    return name, problems, out


def watch(case, scripts):
    name, changes, code, want = case
    with tempfile.TemporaryDirectory() as tmp:
        s = build(tmp, changes)
        rc, out = run(os.path.join(scripts, "watch_pr.sh"),
                      ["81", "--minutes", "0", "--repo", "pompomon/roadgame"], tmp, s)
    problems = [] if rc == code else [f"exit {rc}, want {code}"]
    if want not in out:
        problems.append(f"missing: {want}")
    return name, problems, out


def main():
    parser = argparse.ArgumentParser(description="Runs tools/agent/land_pr.sh and watch_pr.sh against a fake gh.")
    parser.add_argument("names", nargs="*", metavar="scenario", help="run only these scenarios")
    parser.add_argument("--scripts", default=os.path.dirname(HERE),
                        help="the directory of land_pr.sh and watch_pr.sh (default: tools/agent)")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2, help="scenarios run at once")
    parser.add_argument("-v", "--verbose", action="store_true", help="list the scenarios that pass too")
    a = parser.parse_args()
    if shutil.which("jq") is None:
        print("scenarios.py: needs jq, which the fake gh runs for gh's --jq", file=sys.stderr)
        return 2
    # Bash would pass over a fake that it can't run, to the next one on PATH: a real gh, say.
    for fake in ("gh", "date", "sleep"):
        if shutil.which(fake, path=BIN) != os.path.join(BIN, fake):
            print(f"scenarios.py: {os.path.join(BIN, fake)} isn't an executable file", file=sys.stderr)
            return 2
    cases = [(land, c) for c in LAND] + [(watch, c) for c in WATCH]
    unknown = sorted(set(a.names) - {c[0] for _, c in cases})
    if unknown:
        print("scenarios.py: no scenario " + ", ".join(unknown), file=sys.stderr)
        return 2
    cases = [(f, c) for f, c in cases if not a.names or c[0] in a.names]
    scripts = os.path.abspath(a.scripts)
    with concurrent.futures.ThreadPoolExecutor(max(1, a.jobs)) as pool:
        results = list(pool.map(lambda fc: (fc[0].__name__, *fc[0](fc[1], scripts)), cases))
    failed = 0
    for kind, name, problems, out in results:
        if problems:
            failed += 1
            print(f"FAIL {kind} {name}: " + "; ".join(problems))
            print("    | " + out.rstrip("\n").replace("\n", "\n    | "))
        elif a.verbose:
            print(f"PASS {kind} {name}")
    print(f"{len(results) - failed} passed, {failed} failed: tools/agent/test/scenarios.py")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
