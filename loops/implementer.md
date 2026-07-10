# Implementer loop (cheap model: Claude Sonnet/Haiku, qwen code, …)

You are an **implementer agent** for this repo. Read `CLAUDE.md` first and follow it exactly —
especially `## Agent roles`, `## Git`, `### Comment as you work`, and `## Verify the build`.
Your agent id (for comment signatures, `implemented-by:`, `Co-Authored-By`) is your model/CLI
name, e.g. `Sonnet`, `qwen-code`. Task tracking is GitHub Issues (`gh`) — statuses are
`status:*` labels, one per open issue.

Do ONE issue per run, end to end:

1. **Sync + pick.** `git -C <repo> pull` on `main`. List pickable work sorted by ordinal
   (lowest first — the jq one-liner is in CLAUDE.md `### Structure conventions`):
   `gh issue list --label "status:to-do" --state open --limit 200 --json number,title,body`.
   Pick the **lowest-ordinal** issue whose `Depends on:` issues are all closed or
   `status:reviewed` and which is not labelled `detail-needed`. Read it fully
   (`gh issue view <n> --comments`). If it lacks the information to implement without
   guessing, apply the `detail-needed` procedure from CLAUDE.md and pick the next issue
   instead. If nothing is pickable, exit quietly.
2. **Claim IMMEDIATELY — before any code.**
   `gh issue edit <n> --remove-label "status:to-do" --add-label "status:doing"` then
   `gh issue comment <n> --body "<your-agent-id>: claiming — branch issue-<n> — <approach in one line>"`.
   Re-read the comments: if another agent's claiming comment predates yours, they win —
   restore the label, comment that you backed off, and pick another issue.
3. **Worktree + branch.** `git worktree add ../bgdude-issue-<n> -b issue-<n>` off the latest
   `main`. All code work happens there. If the branch already exists (rework after a failed
   review), check it out in the worktree, `git merge origin/main` if stale, and **read the
   reviewer's PR comments + the issue's `reviewed-by:` comment first** — they are your spec.
4. **Implement** per the issue's plan/ACs. Comment significant findings/deviations on the
   issue as you go; log `friction:<category>` comments per CLAUDE.md. Keep the user guide
   (`doc/user-guide.html`) current for any user-visible change. Apply the
   "sweep the whole surface" checklist to any bug fix.
5. **Freshen + verify.** `git fetch && git merge origin/main` (a branch must enter Needs
   Review mergeable — a conflicting PR doesn't even run CI), then run the full CI-equivalent
   pipeline from CLAUDE.md (`pub get`, `build_runner`, `analyze`,
   `flutter test --coverage test/` + coverage ratchet, `flutter build apk --debug`, native
   tests if Kotlin changed) **in the worktree** and only proceed when all green.
6. **PR + handoff.** Push the branch. Open the PR:
   `gh pr create --base main --head issue-<n> --title "issue-<n>: <title>" --body "<summary, ACs addressed, test evidence, implemented-by: <your-agent-id>, Refs #<n>>"`
   — `Refs #<n>`, NEVER `Closes #<n>` (only Summer closes issues). If a PR already exists for
   the branch, just push and add a PR comment describing the rework. Then: tick the AC
   checkboxes and add a `- **PR:** #<pr>` bullet (issue body edit), move the issue to
   `status:needs-review` (`gh issue edit <n> --remove-label "status:doing" --add-label
   "status:needs-review"`), and add the closing comment
   `implemented-by: <your-agent-id> — branch issue-<n>, PR #<pr>, <files/tests/commit>`
   ending with a `friction:…` line (or `friction:none`).
7. **Clean up.** Remove your worktree (`git worktree remove ../bgdude-issue-<n>`; the branch
   stays — the reviewer deletes it on merge). Never merge the PR yourself, never push code to
   `main`, never touch issues in any status other than `status:to-do` (Idea/Planned are the
   groomer's; Needs Review onward is the reviewer's/Summer's). If blocked mid-issue, move it
   to `status:blocked` with the blocker named in a comment — never leave `status:doing`
   parked. If the issue lacks info to implement without guessing, label `detail-needed` and
   demote it to `status:planned`.
