# Stacked PRs

AGENTS.md §4 has the branch names and the commit format. This is how a plan's PRs stack and land (docs/M2.md §4.5).

1. **Stack them.** PR k+1 branches from PR k's branch and targets it, so its diff shows only its own files. CI runs on every PR, but the required checks gate only PRs into `main`. Use one worktree per PR branch, such as `git worktree add ../m2-2 m2/2-car-sim`, so the branches don't mix.
2. **Fix a file on the branch that adds it.** A review fix goes on the branch of the PR that adds the file. Then merge that branch into each later one with `git merge --no-ff --no-edit` ("Merge m2/1-trigger into m2/2-car-sim"). If a later branch changes a file that an earlier PR adds, merging `main` after the squash is an add/add conflict.
3. **Keep inserted lines apart.** A line inserted right next to one that an earlier PR inserts conflicts once that PR is squash-merged. Keep them apart, as M5's `SKID_*` constants are from the `PROP_*` ones (docs/M5.md §4.5), or put them under comments that an earlier PR adds, as M6's legends are (docs/M6.md §5.10).
4. **Only PRs whose base is `main` get merged.** In M0, fix PRs merged into stack branches skipped the required checks, so #16 and #18 had to land them again.
5. **After the owner squash-merges PR k**, update PR k+1:
   ```bash
   git fetch origin main '+refs/heads/m<n>/*:refs/remotes/origin/m<n>/*'
   git switch <PR k+1 branch>
   git merge origin/<PR k branch>     # PR k's final state, in case a fix wasn't merged up yet
   git merge origin/main              # the squash commit
   git diff --name-only origin/main   # must list only PR k+1's files
   git push
   gh pr edit <k+1> --base main       # unless GitHub retargeted it
   ```
   Simulate the merges first with `git merge-tree`. A push like this changes no files in the PR, so it starts no Copilot review (review.md §2).
6. **Retarget before a branch is deleted.** Deleting a merged PR's branch closes each open PR based on it, unless GitHub retargets that PR first. It did for #40–#44 and #47, but deleting `m6/plan` closed #46. GitHub Mobile's "Delete branch" button is reported to close such PRs where github.com's retargets them. A PR closed that way can't be reopened while its base is gone: #46 needed `m6/plan` restored, the PR reopened and retargeted, and the branch deleted again. So once PR k is merged, retarget PR k+1 with `gh pr edit <k+1> --base main` before anyone deletes PR k's branch, or ask the owner to keep the branches until the whole stack has landed.
7. **GitHub's native stacks rebase where these steps merge.** After a squash, GitHub replays each branch's own commits onto it and drops its merges (docs/ROADGEN.md §4.5, docs/DAYNIGHT.md §4.5).
   - Register a stack only once its bottom PR targets `main`: a stack merges into that PR's base, so DN's #70 landed in `dn/plan`.
   - A branch whose own commits were reconciled with the branch below only in a merge can't be replayed. After the squash below, merge only `main` into it, with `-X ours` where both changed the same lines, as #56 did; not the rebased branch below.
   - Don't press **Rebase stack**: it leaves such branches half rebased. Land the PRs one at a time, each set to auto-merge while its checks run, then merge `main` into the next branch as in step 5, unless GitHub rebased it onto the squash. `gh pr merge --auto` merges a PR that is already ready at once, as a direct merge, which starts GitHub's cascade.
