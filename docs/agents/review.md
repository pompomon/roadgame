# Reviews, watching a PR, and CI

How a PR gets reviewed and checked: first by a model of another family (§1), then by Copilot code review on every push (§2), followed with `tools/agent/watch_pr.sh` (§3), and by CI (§4). AGENTS.md §5 has the short version.

## 1. Internal review by a different model

Before you open a PR, and before you push non-trivial fixes, have a subagent of a **different model family** review the change. A reviewer built like you tends to miss what you missed, and each Copilot round costs 2–7 minutes (#26–#28 took 10–11 rounds each).

- **How.** Use the `task` tool of Copilot CLI or the cloud agent. Set `agent_type` to `code-review` for a diff, or `rubber-duck` for a plan or a design. Set `model` to one of another family: a Claude model picks a GPT or Gemini one (such as `gpt-6.1-sol`), and a GPT model picks Claude. The `model` parameter lists the models available. Use `mode: background` and get on with something else, such as negative cases (planning.md §4), but read the result before you push. If no other family is available, use the default model and say so in the PR.
- **The prompt.** The subagent starts with no context. Give it:
  - the goal, with the plan's sections and IDs;
  - how to see the change, such as `git diff origin/main...HEAD`, and the files to read;
  - the rules: "read AGENTS.md §2" and the matching `.github/instructions/` files;
  - the checks you ran and their results;
  - what you want back: high-confidence bugs, missed edge cases, and tests that would pass without the fix. No style comments.
- **After.** Check each finding yourself: reproduce it, or show why it's wrong. Fix the real ones as in §2, each with a test and a negative case. List the model, the findings and what you did in the PR body. Run one review per PR state, plus one after non-trivial fixes. Don't loop until the reviewer finds nothing.

## 2. Copilot code review

Rulesets "Test" (26672445) and "Copilot" (26740665) have Copilot review every push to a PR, 2–7 minutes later (3.3 minutes in the median over #19–#28). Expect several rounds. `watch_pr.sh` prints all three kinds of post:

- **A review** by `copilot-pull-request-reviewer[bot]`. Its body begins with a verdict: 🟢 Approval recommended, 🟡 Changes recommended or 🔵 Needs a closer look. Then comes "No open issues" or "N open issues", and sometimes "N resolved since last review" or "N previously missed issues" (in code you didn't change). A 🔵 review may describe an unpublished finding that has no inline comment, and a 🟢 one can still list an open issue (#3).
- **Inline comments** by `Copilot`, one thread each.
- **PR comments** by `Copilot`, such as a failed setup step (#28: "Install Godot (SHA-512 verified)"). The review may then have missed context, and Copilot's own check, `copilot-pull-request-reviewer`, shows as failed.

**How to answer.**
1. Check each finding against the code, and reproduce it with a test where you can.
2. Fix it on the branch of the PR that owns the code (stacks.md), with a test and a negative case. Put all of a round's fixes in one push: each push starts a new review.
3. Reply in each inline thread. Start with `**Fixed in <sha>.**`, then say what changed, the tests and the negative case, and for a stack `Merged up into #<k> (<sha>).` Use your environment's reply tool if it has one. Otherwise use `gh api repos/pompomon/roadgame/pulls/<n>/comments/<comment-id>/replies -F body=@reply.md` (`-F` reads the file; `-f` would send the text `@reply.md`).
4. Answer findings that have no thread (previously missed or unpublished ones) in one PR comment, as #26 did: `Re [Copilot's review of <sha>](<review URL>), whose overview says …: **Confirmed.** … **Fixed in <sha>.**`
5. Decline with evidence, not opinion: say what you ran and what it showed. #18 checked YAML findings against actionlint and PyYAML, and declined its last one, a bypass of a heuristic check by deliberate shell tricks, as out of the check's scope. When findings turn into ever-rarer edge cases like that, write down the check's scope and stop.
6. Add the fix to the PR body and to the plan's review-fix table (planning.md §3).
7. Don't resolve threads: the owner does.

A 🔵 review with no open issues that only asks for browser or device checks needs no code change (10 of #28's 11 reviews). Do the browser checks yourself (checks.md §3, §4), and list the owner's device checks in the PR body.

**No review?** A push that changes no files in the PR, such as a merge of `main` after a squash, starts none. When the PR needs one, request it: `gh pr edit <n> --add-reviewer @copilot`.

**Large diffs.** Copilot reviews no file whose patch is over about 100 KB, as GitHub leaves its patch out (#34: "Copilot wasn't able to review any files"). Keep a plan under about 95 KB, and split big changes into PRs.

## 3. Watching a PR after each push

After each push to a PR, once your replies are posted, run:

```bash
tools/agent/watch_pr.sh <n>    # polls every 60 s, for up to 15 min
```

It first prints the feedback posted since the head commit. Then it prints each new review, inline comment and PR comment as it arrives, and stops one poll after Copilot's review of the head commit. The summary gives the review's verdict and the checks. `--minutes 0` prints the current state and exits; `--minutes`, `--interval` (at least 10 s) and `--repo` change the defaults.

In Copilot CLI and the cloud agent, run it with the bash tool and a long wait, such as `initial_wait: 600`. If the tool returns before the script ends, the script keeps running: read the rest with `read_bash`, after the completion notice or with a `delay` of a few minutes. Don't poll with `sleep`. If you have other work meanwhile, such as Web checks or negative cases, start it in async mode instead, and read it when you're told that it has ended.

| Exit | Meaning | Do |
|---|---|---|
| 0 | Copilot reviewed the head commit, nothing new needs an answer, and no check failed but Copilot's own. Or the PR is closed, even if feedback came with that | If the summary shows checks still running, `gh pr checks <n> --watch --required`. Then the PR waits for the owner. Once it's closed there's nothing to push: read any feedback printed above, which may ask for a follow-up |
| 2 | Feedback that needs an answer, printed above the summary: any new review but a clean 🟢 one, and any new comment, the owner's too. Or, if you started late, Copilot's review of the head that isn't clean and has no thread reply or post by anyone but Copilot after it | Handle it (§2), push, reply, and watch again. If the last line says someone pushed, pull first |
| 3 | No Copilot review of the head commit in 15 minutes | Look for a setup-failure comment from Copilot, then `gh pr edit <n> --add-reviewer @copilot` and watch once more. If there's still none, tell the owner in a PR comment |
| 4 | The head moved, so someone pushed, and nothing new needs an answer | Pull, then watch again |
| 5 | A check other than Copilot's own failed (named in the summary) | §4, then watch again |
| 1 | Bad arguments, or `gh` failed 3 times in a row | Check `gh auth status` and try again |

- The script can't tell your posts from others'. Replies made with `gh` post as the account it's logged in as: #2–#28's 35 thread replies came from the owner's, `pompomon`. The cloud agent's replies post as `Copilot`, the same login as Copilot's inline comments (#1, #17). Post your replies first: anything new after that came from someone else.
- Repeat the cycle (push, watch, handle) until it exits 0. When a review doesn't come in 15 minutes, follow exit 3 rather than waiting longer.
- If you answer a review without a push (declines only, or a 🔵 review that needs no code change), Copilot won't review again, so there's nothing to wait for. A later run counts a review as answered once a thread reply, or a post by anyone but Copilot, follows it.
- The script counts every check run of the head. When ci.yml's concurrency cancels a duplicate PR run, it exits 5 although GitHub shows the PR clean (#48–#52): judge by the run that completed.

## 4. CI

`ci.yml` runs on every pull request (no branch filter), on pushes to `main` and by hand. Its jobs are `lint`, `test`, `export-web`, and `export-android` for the APK and the AAB; these five are the required checks of ruleset "Test". `test` also fails if the checks changed the tree (AGENTS.md §3). `deploy-web` publishes to GitHub Pages and runs only on `main`. A run takes about 4–6 minutes: `lint` under 20 s, `test` 1–2 min, each export 1–3 min. `release.yml` runs for `v*.*.*` tags or by hand.

When a check fails, read its log: `gh run view <run-id> --log-failed` (`gh pr checks <n>` gives the run's URL). Re-run the known flakes with `gh run rerun <run-id> --failed`:
- GUT's daily update check gets a 403 from GitHub's API rate limit in an editor run, and the scripts reject its `ERROR: [GUT] Could not get version info`. Don't patch `addons/gut/`.
- A download from GitHub times out.

Anything else is a real failure. Reproduce it locally (AGENTS.md §3), fix it, and add a test.
