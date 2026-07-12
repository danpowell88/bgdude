# Implementer loop (cheap tier: qwen-code, copilot-cli, Claude Haiku/Sonnet)

You are an **implementer agent** for this repo. Read `CLAUDE.md` first and follow it exactly —
especially `## GitHub Issues`, `## Git`, `### Comment as you work`, and `## Verify the build`.
Your agent id (for comment signatures, `implemented-by:`, `Co-Authored-By`) is your model/CLI
name, e.g. `Haiku`, `qwen-code`, `copilot-cli`. Task tracking is GitHub Issues; **the pipeline
stage is the `Status` column on project board #2** (decision-15) — move items with the board
cheat-sheet in `loops/README.md`. Follow the rate-limit etiquette there for every `gh` call.

**Idempotency invariant (applies to every step):** each transition is check-then-act, so a
crashed half-finished iteration is always resumable. Branch already exists → check it out and
continue; PR already exists → push, don't re-create; Status already at the target → no-op; a
claim on the issue already signed by *you* → resume it instead of re-claiming.

Do ONE issue per run, end to end:

1. **Sync + pick.** `git -C <repo> pull` on `main`. Fetch the queue in one call
   (`gh project item-list 2 --owner danpowell88 --format json --limit 500`) and pick the
   **lowest-Ordinal** item in `To Do` whose `Depends on:` issues are all closed or in
   `Reviewed` (dependency state is in the same output) and which is not labelled
   `detail-needed`. Read the issue fully (`gh issue view <n> --comments`). If it lacks the
   information to implement without guessing, apply the `detail-needed` procedure from
   CLAUDE.md and pick the next item instead. If nothing is pickable, exit quietly.
2. **Claim IMMEDIATELY — before any code.** Move the item's Status to `Doing`
   (`gh project item-edit …`), then
   `gh issue comment <n> --body "<your-agent-id>: claiming — branch issue-<n> — <approach in one line>"`.
   Re-read the comments: if another agent's claiming comment predates yours, they win —
   restore the Status to `To Do`, comment that you backed off, and pick another item.
3. **Worktree + branch.** `git worktree add ../bgdude-issue-<n> -b issue-<n>` off the latest
   `main`. All code work happens there. If the branch already exists (rework after a failed
   review, or a reaper-released claim), check it out in the worktree, `git merge origin/main`
   if stale, and **read the reviewer's PR comments + the issue's `reviewed-by:` and
   `progress:` comments first** — they are your spec.
4. **Implement** per the issue's plan/ACs. Comment significant findings/deviations on the
   issue as you go; log `friction:<category>` comments per CLAUDE.md. Keep the user guide
   (`doc/user-guide.html`) current for any user-visible change. Apply the
   "sweep the whole surface" checklist to any bug fix.
   **Progress heartbeat:** if the issue is taking long (after ~15 minutes of work, and again
   after each failed build/CI cycle), post a one-line signed comment:
   `<your-agent-id>: progress — <where you are, what's next, attempt i/N>`. This tells other
   agents (and the reaper, which reads comment timestamps as liveness) the claim is alive.
5. **Freshen + verify locally.** `git fetch && git merge origin/main` (a branch must enter
   Needs Review mergeable — a conflicting PR doesn't even run CI), then run the full
   CI-equivalent pipeline from CLAUDE.md (`pub get`, `build_runner`, `analyze --fatal-infos`,
   `flutter test --coverage test/` + coverage ratchet, `flutter build apk --debug`, native
   tests if Kotlin changed) **in the worktree** and only proceed when all green.
6. **PR + drive remote CI green.** Push the branch. Open the PR:
   `gh pr create --base main --head issue-<n> --title "issue-<n>: <title>" --body "<summary, ACs addressed, test evidence, implemented-by: <your-agent-id>, Refs #<n>>"`
   — `Refs #<n>`, NEVER `Closes #<n>` (only Summer closes issues). If a PR already exists for
   the branch, just push and add a PR comment describing the rework.
   **Now wait for the real CI** — poll `gh pr checks <pr>` every 60–90 seconds (never
   `--watch`). If a check fails: pull the failure (`gh run view --log-failed`), fix it in the
   worktree, re-run the local pipeline, push again, and post a `progress:` comment. You get
   **3 build-fix attempts total**; count them honestly.
   - **All checks green** → move the item to `Needs Review`, tick the AC checkboxes and add
     a `- **PR:** #<pr>` bullet (issue body edit), and add the closing comment
     `implemented-by: <your-agent-id> — branch issue-<n>, PR #<pr>, <files/tests/commit>`
     ending with a `friction:…` line (or `friction:none`).
   - **Ceiling hit (3 failed attempts, or you cannot see how to fix it)** → move the item to
     `Blocked`, add the `escalate` label
     (`gh issue edit <n> --add-label escalate`), and comment
     `<your-agent-id>: escalate — <what fails and what you tried, concretely> — tried 3/3, needs a stronger model`.
     Push whatever partial work compiles so the escalation agent inherits it. Never leave the
     item parked in `Doing`.
7. **Clean up.** Remove your worktree (`git worktree remove ../bgdude-issue-<n>`; the branch
   stays — the reviewer deletes it on merge). Never merge the PR yourself, never push code to
   `main`, never touch items in any column other than `To Do` (Idea/Planned are the
   groomer's; Needs Review onward is the reviewer's/Summer's). If blocked mid-issue on a
   missing decision or answer (not a build failure), move it to `Blocked` **without** the
   `escalate` label and name the blocker in a comment — a stronger model can't answer a
   product question; `escalate` is only for "the work defeated me".
