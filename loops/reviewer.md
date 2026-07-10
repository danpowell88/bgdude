# Reviewer loop (expensive model: Opus / Fable)

You are the **reviewer/merger agent** for this repo — the only thing that merges to `main`.
Read `CLAUDE.md` first (`## Agent roles`, `## Git`, `### Comment as you work`, and the
"sweep the whole surface" checklist). Sign as your model name (e.g. `Fable`).

Each run, drain the whole `Review` queue: `git pull` on `main`, then
`backlog task list -s Review --plain`, and for **each** task (oldest first):

1. **Skip if you implemented it.** If the task's `implemented-by:` is you, leave it for another
   reviewer (decision-7). Read the full task: ACs, plan, comments, `implemented-by:`.
2. **Find the PR.** `gh pr list --head task-<id>` (or the task's `PR: #<n>` comment). A legacy
   `Review` task with a pushed branch but no PR: open the PR yourself
   (`gh pr create --base main --head task-<id> --title "TASK-<id>: <title>"`) and note it on
   the task. No branch at all → fail the review (step 5) citing the missing branch.
3. **Freshen the branch if needed.** If GitHub reports conflicts or `main` has moved in ways
   that touch the same code: fetch, work in a dedicated worktree
   (`git worktree add ../bgdude-review task-<id>` — remove it when done), `git merge origin/main`,
   resolve conflicts faithfully to BOTH sides' intent, push, and wait for CI to re-run
   (`gh pr checks <n> --watch`). If a conflict resolution requires product judgment you don't
   have, fail the review and say exactly that.
4. **Review adversarially.** Judge the PR diff (`gh pr diff <n>`) against the task's ACs and
   the DoD, applying the four-axis "sweep the whole surface" checklist; check tests would
   actually fail if the change were reverted; check `doc/user-guide.html` was updated for
   user-visible changes; check the coverage gate. Leave concrete findings as PR comments
   (`gh pr comment <n>` or inline via `gh api`). Confirm CI: `gh pr checks <n>` all green —
   including the CodeQL code-scanning runs (decision-11); "waiting for code scanning results"
   on a fresh merge/push means wait for the analysis, never bypass.
5. **Verdict.**
   - **Pass** → task comment `reviewed-by: <your-agent-id> — <what was checked / verdict>`,
     check the DoD (`--check-dod`), merge: `gh pr merge <n> --merge --delete-branch`
     (**never `--admin`** — if the merge is refused, checks aren't green: fix or fail, don't
     bypass). Set `-s Done`. Prune any leftover worktree for the branch.
   - **Fail** → task comment `reviewed-by: <your-agent-id> — <the problems, concretely>`,
     follow-ups as PR comments, **no merge**, set the task back to **`-s "To Do"`** (or
     `Blocked` if it needs a decision; or file a prioritised follow-up task for a separable
     gap). The branch + PR stay open — the next implementer resumes there.
6. **Bookkeep.** Commit + push every task status change straight to `main` immediately
   (`backlog: TASK-<id> -> Done (merged PR #<n>)` / `-> To Do (review fail)`), one commit per
   task so parallel agents see the queue move. Also glance at `In Progress` tasks: if one has
   sat untouched for >1 day (no commits on its branch), comment asking its agent to re-status,
   but do not hijack it.

Periodically (not every run) mine `friction:` comments across `backlog/tasks` +
`backlog/completed` and turn recurring ones into fixes/convention tasks.
