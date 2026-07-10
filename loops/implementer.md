# Implementer loop (cheap model: Claude Sonnet/Haiku, qwen code, …)

You are an **implementer agent** for this repo. Read `CLAUDE.md` first and follow it exactly —
especially `## Agent roles`, `## Git`, `### Comment as you work`, and `## Verify the build`.
Your agent id (for `--comment-author`, `implemented-by:`, `Co-Authored-By`) is your model/CLI
name, e.g. `Sonnet`, `qwen-code`.

Do ONE task per run, end to end:

1. **Sync + pick.** `git -C <repo> pull` on `main`. Run `backlog task list -s "To Do" --plain`
   and pick the **lowest-ordinal** task whose `dependencies` are all Done and which is not
   labelled `detail-needed`. Read it fully (`backlog task <id> --plain`). If it lacks the
   information to implement without guessing, apply the `detail-needed` procedure from
   CLAUDE.md and pick the next task instead. If nothing is pickable, exit quietly.
2. **Claim IMMEDIATELY — before any code.** `backlog task edit <id> -s Doing -a <your-agent-id>
   --comment "branch: task-<id>" --comment "Started: <approach>" --comment-author "<your-agent-id>"`,
   then commit **only** the task file to `main` and push
   (`git add "backlog/tasks/task-<id>*.md" && git commit -m "backlog: claim TASK-<id> (Doing)" && git push`).
   If the push is rejected (someone else moved `main`), pull --rebase and re-check the task is
   still unclaimed before pushing again; if it got claimed, pick another task.
3. **Worktree + branch.** `git worktree add ../bgdude-task-<id> -b task-<id>` off the latest
   `main`. All code work happens there. If the branch already exists (rework after a failed
   review), check it out in the worktree, `git merge origin/main` if stale, and **read the
   reviewer's PR comments + the task's `reviewed-by:` comment first** — they are your spec.
4. **Implement** per the task's plan/ACs. Comment significant findings/deviations on the task
   as you go; log `friction:<category>` comments per CLAUDE.md. Keep the user guide
   (`doc/user-guide.html`) current for any user-visible change. Apply the
   "sweep the whole surface" checklist to any bug fix.
5. **Freshen + verify.** `git fetch && git merge origin/main` (a branch must enter Needs Review
   mergeable — `main` churns fast here, TASK-310), then run the full CI-equivalent pipeline
   from CLAUDE.md (`pub get`, `build_runner`, `analyze`, `flutter test --coverage test/` +
   coverage floor, `flutter build apk --debug`, native tests if Kotlin changed) **in the
   worktree** and only proceed when all green.
6. **PR + handoff.** Push the branch. Open the PR:
   `gh pr create --base main --head task-<id> --title "TASK-<id>: <title>" --body "<summary, ACs addressed, test evidence, implemented-by: <your-agent-id>>"`
   (if a PR already exists for the branch, just push and add a PR comment describing the rework).
   Then: check off ACs (`--check-ac`), add the closing comment
   `implemented-by: <your-agent-id> — branch task-<id>, PR #<n>, <files/tests/commit>` ending
   with a `friction:…` line (or `friction:none`), record `--comment "PR: #<n>"`, set
   `-s "Needs Review"`, and commit+push the task-file change straight to `main`
   (`backlog: TASK-<id> -> Needs Review (PR #<n>)`).
7. **Clean up.** Remove your worktree (`git worktree remove ../bgdude-task-<id>`; the branch
   stays — the reviewer deletes it on merge). Never merge the PR yourself, never push code to
   `main`, never touch tasks in any status other than `To Do` (Idea/Planned are the
   groomer's; Needs Review onward is the reviewer's/Summer's). If blocked mid-task, set `-s Blocked` with the
   blocker named (commit+push that too) — never leave `Doing` parked. If the task lacks
   info to implement without guessing, label `detail-needed` and demote it to `Planned`.
