---
id: TASK-309
title: >-
  CI does not run on task-<id> branches, so the review-merge gate can never
  confirm green
status: In Progress
assignee:
  - Claude
created_date: '2026-07-10 12:26'
updated_date: '2026-07-10 12:37'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 111000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The decision-8 review-and-merge workflow requires the review loop to confirm CI is green on a task branch before merging it to main. But .github/workflows/ci.yml only triggers on push to main and pull_request against main. A task-<id> branch pushed on its own (the normal decision-8 flow: push branch, move task to Review, loop merges) gets NO CI run. Observed 2026-07-10: 10 task branches in Review (task-142/143/151/152/153/154/155/163/266/306) have zero CI runs; the only branch with CI is worktree-bgdude-impl, and only because TASK-141 has an open PR #1 (pull_request trigger). So the merge gate condition can never be satisfied for the standard flow, and every review firing correctly refuses to merge -- the Review queue backs up indefinitely. This is the root blocker of the whole feature-branch workflow, not a per-task issue.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CI runs on every task-<id> branch so the review loop can confirm green before merging -- either add task-** (and worktree-* if used) to the ci.yml push trigger, OR make the workflow open a PR per task branch (pull_request already triggers CI, as TASK-141 shows)
- [ ] #2 Decide and document which mechanism (branch-push CI for local --no-ff merge per decision-8, vs PR-per-branch) and update decision-8 / CLAUDE.md to match
- [ ] #3 A branch in Review reliably has a visible green CI run the loop can key off (gh run list --branch <b> or the PR checks)
- [ ] #4 The paths-ignore (backlog/doc/md) still applies so pure-bookkeeping branches do not burn CI
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: review-and-merge loop 2026-07-10 -- gate blocked because no task branch has CI (friction:tooling / friction:build)
- File: .github/workflows/ci.yml on: push branches [main] + pull_request branches [main]
- Blocks decision-8 end to end; the 11-task Review queue cannot drain until this is fixed
- Interacts with the GitHub-App connection (PRs work -- PR #1 ran CI); local --no-ff merge does not need the app but does need branch-push CI to confirm green
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 12:37
---
branch: task-309
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
- [ ] #10 Reviewed by a different agent than the implementer -- a reviewed-by comment is present and the task passed through Review before Done
<!-- DOD:END -->
