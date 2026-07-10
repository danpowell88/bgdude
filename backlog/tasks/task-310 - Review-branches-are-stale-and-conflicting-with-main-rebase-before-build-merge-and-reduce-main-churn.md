---
id: TASK-310
title: >-
  Review branches are stale and conflicting with main -- rebase before
  build/merge, and reduce main churn
status: To Do
assignee:
  - Claude
created_date: '2026-07-10 13:08'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 110500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enabling branch CI (task-** trigger, TASK-309) exposed the real jam: all ~36 Review-status branches are badly behind main and CONFLICTING, so they cannot build or merge. Measured 2026-07-10: task-306/142/151 are 21 commits behind main, task-153 18, task-155 14, task-163 11; a smoke-test PR (task-306 -> main, #2) came back mergeStateStatus DIRTY / mergeable CONFLICTING, and GitHub skips CI on an unmergeable PR (that is why no checks ran). Root cause: main churns fast from the decision-8 straight-to-main bookkeeping carve-out (every follow-up ticket, decision, CLAUDE.md/ci.yml/config/doc edit lands on main directly), so feature branches cut off main go stale within hours and start conflicting. The review-merge gate therefore never clears -- the queue has grown from a handful to 36 while every branch rots. Two fixes needed: (1) branches must be brought up to date with main (git merge origin/main or rebase + resolve conflicts + re-push) before they are reviewable/mergeable -- this is the implementer's job per reviewer != implementer, not the review loop's; (2) reduce or batch the main churn so branches do not go stale so fast (e.g. bookkeeping commits batched, or branches rebased onto main automatically when moved to Review).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every Review-status branch is up to date with main (no conflicts) before it is eligible for the merge gate; a stale branch is bounced to In Progress with a rebase-needed note rather than sat in Review
- [ ] #2 The implementer rebases/merges main into a branch as part of moving it to Review (documented in CLAUDE.md), so branches enter Review mergeable
- [ ] #3 Main churn is reduced or batched so branches do not go 10-20 commits stale within hours (decide: batch bookkeeping, shorter-lived branches, or auto-rebase-on-Review)
- [ ] #4 The 36 currently-stale branches are reconciled (rebased) or explicitly abandoned/re-cut
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: review-and-merge loop 2026-07-10, kicking off branch builds -- friction:tooling / friction:process
- Evidence: git rev-list behind counts above; PR #2 CONFLICTING; TASK-309 (CI trigger) is necessary but not sufficient
- Interacts with decision-8 (straight-to-main bookkeeping is the churn source) -- may need a decision update
- Blocks the entire Review queue (36 tasks) from draining
<!-- SECTION:NOTES:END -->

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
