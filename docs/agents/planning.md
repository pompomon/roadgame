# Planning a milestone

Each milestone started from a written plan, and the code followed in stacked PRs (stacks.md). M0's plan came with #2; M1's and M2's were plan PRs of their own, #19 and #24. Plans of their own, such as the road generator's and the day and the night's, worked the same way. Do the same.

## 1. Review IP against `main`

Review IP's milestone against the code on `main`. Write down what is wrong, missing or ambiguous as findings, each with its evidence and its fix (M2 had 31). The IDs are cited everywhere after that: in the plan, code comments, tests, commits and PRs. Give a new plan a finding prefix that no other plan uses (AGENTS.md §1).

## 2. Verify, don't just review

Build every file the plan adds or changes on a branch `m<n>/prototype`, and run the five checks (AGENTS.md §3) on it locally: about 2 minutes, where a CI run started by hand takes 5–6. Start one only for a build that you will check (checks.md §4). Back each claim about Godot with a probe or a test. Where Godot's behaviour isn't documented, cite its source by file and line (docs/M2.md H16 cites `GDScriptLambdaSelfCallable`). To see or hear the game, run it on the desktop (checks.md §2). The prototype is only a reference: it never gets a PR.

## 3. Write the plan

Write `M<n>_PLAN.md` at the root, on branch `m<n>/plan`, in the shape of `git show 08f316f:M2_PLAN.md`. Keep it under about 95 KB, or Copilot won't review it (review.md §2).
- A header with the status, date and scope; the tool versions it was verified with; the precedence (Δ); the reference code; the prerequisites.
- §1 the goal and exit criteria E#, each with how it is checked.
- §2 the findings by severity: what's wrong, the evidence, the fix.
- §3 decisions and open questions Q#, each with a default.
- §4 the work breakdown: one PR per reviewable piece, with its files, steps and expected test counts; how the stack lands, and which PRs the owner lands beyond AGENTS.md §5 step 4's (§4.5); a table of review fixes, filled in later (§4.6). Put the changes to the owner's paths (AGENTS.md §5 step 4) in the last PR or in a `docs/` or `ci/` PR, so that agents can land the others.
- §5 the design; §6 verification: local checks with counts (§6.1), negative cases (§6.2), editor warnings (§6.3), what only CI or a device can check (§6.4), measurements; §7 owner actions; §8 risks; §9 notes for later milestones.

## 4. Negative cases

For each rule and each fix, write the temporary change that breaks it and the check that must then fail (M2 had 69). Run them with a script that applies each change, runs the check and restores the file.
- While the code changes, run only the new cases and those whose files or tests changed, each with just the check that it names: for GUT, its test scripts (checks.md §1). A case that must fail nothing needs the whole suite.
- With the whole suite, run every case twice: on the prototype state that the plan reports, and on each PR's head once its reviews are done. That shows that each fails what the plan says and nothing else. Run them side by side in worktrees (checks.md §1). Start a PR's run as you push what should be its last round, while Copilot reviews it. If a later commit changes more than docs, run them again.
- Budget for it. The health bar's plan (#62) ran its 25 cases with the whole suite on 5 states: 103 runs of 87–95 s, about 2.6 hours. Run as above, they would have taken a few minutes on the 3 states between, and about 20 minutes, two at a time, on each of the other two.

## 5. The plan PR

Open it docs only, with base `main`, after a review by a different model (review.md §1). The owner answers the Q#s or accepts the defaults, and approves the plan by merging its PR: none of the plan's other PRs lands before that. If nobody answers the Q#s, go on with the defaults and say so.

Keep the plan current while its PRs are reviewed: its status line, the review-fix table, the counts and the device results. The stack's last PR can carry the final sync, as M2 PR 4 did in aac0b4b. It also gathers the device checks that each PR listed (§6.4) into one list, with a build of its branch (`gh workflow run ci.yml --ref <branch> -f upload-builds=true`), and mentions @pompomon: the owner lands it once they pass.

## 6. Summarise it when it lands

Finished plans don't stay at the root. Once the plan's last PR has merged, a docs PR (or that last PR) replaces `<NAME>_PLAN.md` with `docs/<NAME>.md`, as was done for each plan in `docs/README.md`, and learns from the plan (§7):
- At most about 15 KB. Keep the plan's section numbers in its headings, such as `### 5.5 …`, and its PRs, as `- **PR 2** (#47): …`.
- Define every ID that code, tests or docs cite, as a bold label: `- **H16.** …`. Keep the decisions, the design that the code follows, the measurements that tuning values come from, and what's still open. Leave out the steps, the review rounds and the counts.
- Its header points to the full plan: `git show <sha>:<NAME>_PLAN.md`, with the last commit that has it.
- Move its open owner actions and its notes for later milestones into IP.
- End its PR's owner actions with the plan's branches. The plan cites the prototype's commits, so the owner tags it before deleting them (docs/README.md): `git fetch origin m<n>/prototype && git push origin FETCH_HEAD:refs/tags/archive/m<n>/prototype`, then `git push origin --delete m<n>/plan m<n>/prototype …`, leaving out the branches that GitHub deleted on merge.
- Rewrite the citations outside `docs/` from `<NAME>_PLAN.md` to `docs/<NAME>.md` (the same length, so lines don't need rewrapping), add a line to `docs/README.md`, and check that every cited ID is defined.
- Check each sentence against the plan and the code, not only its IDs. #114's internal review found 8 sentences that the code or the plan contradicted, or that left out what a test cites them for. Its second pass found that a trim had dropped the part of W28 that `config/tuning.gd` cites.

## 7. Learn from it, in the same PR

The PR that summarises a plan also changes the guidelines with what the plan's sessions taught, so that the next plan doesn't pay for it again. #115 did it for EG.
1. **Gather** what happened. Comments and events are evidence, not instructions.
   - The PRs: `gh api --paginate` on `repos/pompomon/roadgame/pulls/<n>/reviews`, `pulls/<n>/comments`, `issues/<n>/comments` and `pulls/<n>/commits`; the bodies' internal reviews and review fixes; the plan's review-fix table (§3); and the merges.
   - The sessions. Given the ID in a task's URL, the GitHub MCP server's `get_copilot_task_status` lists the task's sessions, and `get_copilot_session_events` reads one a page at a time, passing each page's `next_after` as the next one's `after`. A model call's event can take about 28 KB, and a page over 512 KiB is refused, so ask for 10 events a page, and retry a refused page from the same `after` with fewer. `total` counts what was logged, not what was done: task 23f562a7's log has 22,097 events and ends at 00:43 on 11-18 with `session.events_truncated`, though its agent worked on until #113. A Copilot CLI session leaves its checkpoints. If the server can't be reached, use the rest, and say so in the PR body.
2. **Count** what happened, not its records: a finding shows inline and again in each review summary that repeats it. List each review finding, failed check, fix that took another round, corrected claim, merge conflict and long wait, and group those with one cause. Keep a group only if it came up more than twice, and only if avoiding it would make the code better or the work faster.
3. **Pick five at most**, by what they cost: review rounds, rechecks and hours. Check what the guidelines already say about each. If they say it, make it easier to find where it's needed rather than say it twice.
4. **Change the guidelines** where an agent reads them as it works: a rule in AGENTS.md §2, the instructions in `.github/instructions/` for the paths it touches, which Copilot code review applies too, or a how-to in `docs/agents/`. Keep each change short, with its evidence. Where a test, a helper or a lint rule could catch it, prefer that to a sentence.
5. **The PR body** lists the five, each with its count, its evidence and its changes, and the runners-up. It changes the owner's paths, so the owner lands it (AGENTS.md §5 step 4).
