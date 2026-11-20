# Stacked PRs

AGENTS.md §4 has the branch names and the commit format. This is how a plan's PRs stack and land (docs/M2.md §4.5).

1. **Stack them.** PR k+1 branches from PR k's branch and targets it, so its diff shows only its own files. CI runs on every PR, but the required checks gate only PRs into `main`. Use one worktree per PR branch, such as `git worktree add ../m2-2 m2/2-car-sim`, so the branches don't mix.
2. **Fix a file on the branch that adds it.** A review fix goes on the branch of the PR that adds the file. Then merge that branch into each later one with `git merge --no-ff --no-edit` ("Merge m2/1-trigger into m2/2-car-sim"). If a later branch changes a file that an earlier PR adds, merging `main` after the squash is an add/add conflict.
3. **Keep inserted lines apart.** A line inserted right next to one that an earlier PR inserts conflicts once that PR is squash-merged. Keep them apart, as M5's `SKID_*` constants are from the `PROP_*` ones (docs/M5.md §4.5), or put them under comments that an earlier PR adds, as M6's legends are (docs/M6.md §5.10).
4. **Only PRs whose base is `main` get merged, and agents land them.** In M0, fix PRs merged into stack branches skipped the required checks, so #16 and #18 had to land them again.

   Once the owner has merged the plan's PR, which approves the plan, agents land its other PRs one at a time, bottom up, unless the owner lands them (AGENTS.md §5 step 4). When `watch_pr.sh` exits 0, run `tools/agent/land_pr.sh <n>`, with a long wait such as `initial_wait: 600`. It lands the PR only if:
   - its branch is `<prefix>/<k>-<slug>` in this repository, and a PR from `<prefix>/plan` has merged into `main`;
   - its base is `main`, and was all the while it ran, and it's open, not a draft and not labelled `needs-owner`;
   - if it was based on other branches before, a PR from each of them has merged into `main`. Retargeted to `main` before the PR below it landed, it would bring that PR in with its own;
   - its diff with `main`'s tip, which is what the merge brings in whatever the PR's base, changes none of the paths that the owner lands (AGENTS.md §5 step 4), counting a renamed file's old path too. GitHub lists up to 300 files, so a diff of 300 or more is the owner's;
   - `watch_pr.sh <n> --minutes 0` exits 0, on each pass: Copilot reviewed the head, and nothing needs an answer. If that review isn't clean, a PR comment answers it, starting with a link to it (review.md §2 item 4); a thread reply doesn't. So does one for each person's PR comment or review, however old, so a restart clears no hold;
   - nothing came while it ran but Copilot's reviews that `watch_pr.sh` judged: any other review or comment stops it, to be answered first;
   - no review thread is open;
   - it's up to date with `main` and doesn't conflict with it;
   - `main`'s rules require branches to be up to date and conversations to be resolved before merging, so GitHub checks both again at the merge. The head pin below covers only pushes to the PR, not a merge into `main` or a new thread. If either rule is off, it lands nothing;
   - the latest run of each required check on the head passed, among the PR's own runs, as GitHub's merge box counts them;
   - the CI run of `main`'s tip passed, so nothing lands on a broken `main`. For a known flake (review.md §4), it prints the command that re-runs it; tell the owner of anything else.

   It checks the gate every `--interval` (60) seconds, for up to `--minutes` (20) while checks or `main`'s CI run are still running. On each pass it reads the PR and its feedback last, after `watch_pr.sh`, so a label, a retarget or a comment that comes while it checks still stops it. Then it squash-merges the PR with GitHub's default message, pinned with `--match-head-commit` to the head that Copilot reviewed: GitHub refuses the merge if anyone pushed since. Then it retargets the open PRs still based on the PR's branch to `main`. `--check` only reports the gate.

   | Exit | Do |
   |---|---|
   | 0 | Landed, or it already was: update the next PR (step 5) |
   | 2 | Fix each `no` line, or label the PR `needs-owner` and say why in a comment |
   | 3 | Still waiting after `--minutes`, for checks or the CI run of `main`'s tip: run it again |
   | 1 | Check `gh auth status` and try again |

   Don't set auto-merge instead: GitHub keeps it on through later pushes by anyone who can write, agents included, so a fix pushed after the review would land unreviewed.
5. **After PR k is squash-merged**, update PR k+1:
   ```bash
   git fetch origin main '+refs/heads/m<n>/*:refs/remotes/origin/m<n>/*'
   git switch <PR k+1 branch>
   git merge origin/<PR k branch>     # PR k's final state, in case a fix wasn't merged up yet
   git merge origin/main              # the squash commit
   git diff --name-only origin/main   # must list only PR k+1's files
   git push
   gh pr edit <k+1> --base main       # unless GitHub or land_pr.sh retargeted it
   gh pr edit <k+1> --add-reviewer @copilot
   ```
   Simulate the merges first with `git merge-tree`. If PR k's branch is already deleted, merge its last state with `git fetch origin pull/<k>/head && git merge FETCH_HEAD`. A push like this changes no files in the PR, so it starts no Copilot review (review.md §2); landing needs one of the head, so request it.

   **If merging `main` conflicts.** Once PR k is squashed, a line that PR k+1 changes, or inserts next to one of PR k's, conflicts (steps 2 and 3): 5 of EG's 9 merges of `main` did, in 20 files. When nothing else has landed since PR k, `main`'s tree is that of PR k's head, which the branch has just merged (`origin/<PR k branch>` or `pull/<k>/head`). Then the branch lacks nothing from `main`, and its side of each conflict is right. With a clean worktree:
   ```bash
   git merge --abort
   before=$(git rev-parse HEAD)
   git merge -X ours origin/main && git diff --quiet <PR k's head> HEAD^2 && git diff --quiet "$before" HEAD
   ```
   The two diffs check that the `main` merged is PR k's tree and that the merge changed no file: each of EG's five merges passed both. If any of the three commands fails, undo the merge and resolve the conflicts by hand. Run `git merge --abort` if the merge stopped on a conflict that `-X ours` doesn't settle, such as a file that one side deletes, or `git reset --keep "$before"` once it has committed.
6. **Retarget before a branch is deleted.** Deleting a merged PR's branch closes each open PR based on it, unless GitHub retargets that PR first. It did for #40–#44 and #47, but deleting `m6/plan` closed #46. GitHub Mobile's "Delete branch" button is reported to close such PRs where github.com's retargets them. A PR closed that way can't be reopened while its base is gone: #46 needed `m6/plan` restored, the PR reopened and retargeted, and the branch deleted again. So once PR k is merged, retarget PR k+1 with `gh pr edit <k+1> --base main` before anyone deletes PR k's branch by hand. `land_pr.sh` retargets them as soon as it has merged. With "Automatically delete head branches" on (Settings → General), GitHub deletes the branch at the merge itself, and retargets the PRs based on it rather than closing them, as its docs say ("Merging a pull request").
7. **GitHub's native stacks rebase where these steps merge.** After a squash, GitHub replays each branch's own commits onto it and drops its merges (docs/ROADGEN.md §4.5, docs/DAYNIGHT.md §4.5).
   - Don't register a stack whose PRs agents land: `land_pr.sh` merges directly, which starts GitHub's cascade (below). The owner lands a registered stack.
   - Register a stack only once its bottom PR targets `main`: a stack merges into that PR's base, so DN's #70 landed in `dn/plan`.
   - A branch whose own commits were reconciled with the branch below only in a merge can't be replayed. After the squash below, merge only `main` into it, with `-X ours` where both changed the same lines, as #56 did; not the rebased branch below.
   - Don't press **Rebase stack**: it leaves such branches half rebased. Land the PRs one at a time, each set to auto-merge while its checks run, then merge `main` into the next branch as in step 5, unless GitHub rebased it onto the squash. `gh pr merge --auto` merges a PR that is already ready at once, as a direct merge, which starts GitHub's cascade.
