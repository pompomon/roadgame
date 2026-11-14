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
- §4 the work breakdown: one PR per reviewable piece, with its files, steps and expected test counts; how the stack lands (§4.5); a table of review fixes, filled in later (§4.6).
- §5 the design; §6 verification: local checks with counts (§6.1), negative cases (§6.2), editor warnings (§6.3), what only CI or a device can check (§6.4), measurements; §7 owner actions; §8 risks; §9 notes for later milestones.

## 4. Negative cases

For each rule and each fix, write the temporary change that breaks it and the check that must then fail (M2 had 69). Run them with a script that applies each change, runs the check and restores the file.
- While the code changes, run only the new cases and those whose files or tests changed, each with just the check that it names: for GUT, its test scripts (checks.md §1). A case that must fail nothing needs the whole suite.
- With the whole suite, run every case twice: on the prototype state that the plan reports, and on each PR's head once its reviews are done. That shows that each fails what the plan says and nothing else. Run them side by side in worktrees (checks.md §1). Start a PR's run as you push what should be its last round, while Copilot reviews it. If a later commit changes more than docs, run them again.
- Budget for it. The health bar's plan (#62) ran its 25 cases with the whole suite on 5 states: 103 runs of 87–95 s, about 2.6 hours. Run as above, they would have taken a few minutes on the 3 states between, and about 20 minutes, two at a time, on each of the other two.

## 5. The plan PR

Open it docs only, with base `main`, after a review by a different model (review.md §1). The owner answers the Q#s or accepts the defaults. If nobody answers, go on with the defaults and say so.

Keep the plan current while its PRs are reviewed: its status line, the review-fix table, the counts and the device results. The stack's last PR can carry the final sync, as M2 PR 4 did in aac0b4b.

## 6. Summarise it when it lands

Finished plans don't stay at the root. Once the plan's last PR has merged, a docs PR (or that last PR) replaces `<NAME>_PLAN.md` with `docs/<NAME>.md`, as was done for M0–M6 and the four plans after them:
- At most about 15 KB. Keep the plan's section numbers in its headings, such as `### 5.5 …`, and its PRs, as `- **PR 2** (#47): …`.
- Define every ID that code, tests or docs cite, as a bold label: `- **H16.** …`. Keep the decisions, the design that the code follows, the measurements that tuning values come from, and what's still open. Leave out the steps, the review rounds and the counts.
- Its header points to the full plan: `git show <sha>:<NAME>_PLAN.md`, with the last commit that has it.
- Move its open owner actions and its notes for later milestones into IP.
- End its PR's owner actions with the plan's branches. The plan cites the prototype's commits, so the owner tags it before deleting them (docs/README.md): `git fetch origin m<n>/prototype && git push origin FETCH_HEAD:refs/tags/archive/m<n>/prototype`, then `git push origin --delete m<n>/plan m<n>/prototype …`.
- Rewrite the citations outside `docs/` from `<NAME>_PLAN.md` to `docs/<NAME>.md` (the same length, so lines don't need rewrapping), add a line to `docs/README.md`, and check that every cited ID is defined.
