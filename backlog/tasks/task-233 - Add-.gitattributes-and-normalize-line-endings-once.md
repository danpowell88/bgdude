---
id: TASK-233
title: Add .gitattributes and normalize line endings once
status: To Do
assignee: []
created_date: '2026-07-07 04:50'
labels:
  - infra
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 113240
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Commit 9cd4363 (TASK-149) flipped `lib/feedback/confirmation_service.dart` from CRLF to LF, recording a 283-line diff for a ~40-line feature — destroying `git blame` for the file and burying the real change. The repo has no `.gitattributes` and `core.autocrlf=false`, so file endings are inconsistent and any editor that normalizes on save will repeat this.

**Reason for change.** Deterministic endings keep diffs reviewable and blame useful; one deliberate normalization beats accidental per-file flips forever.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A `.gitattributes` with `* text=auto eol=lf` (binary globs excluded) committed
- [ ] #2 One-time `git add --renormalize .` commit applied when no other session has files in flight, isolated from any code change
- [ ] #3 CI green after the normalization commit
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Author `.gitattributes` (text=auto eol=lf; mark png/jpg/mp4/jar/task binaries).
- Coordinate a quiet window; run `git add --renormalize .` as a standalone commit.
- Verify: `flutter analyze` clean, `flutter test` green; CI green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #2 (finding 2)
- Effort: S
- Where: .gitattributes (new), repo-wide renormalization
- Related: 9cd4363 (the CRLF flip)
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
