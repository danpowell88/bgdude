---
id: TASK-149
title: Produce siteFailure confirmations from StubbornHighDetector
status: To Do
assignee: []
created_date: '2026-07-06 08:42'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - insights
milestone: m-8
dependencies: []
priority: medium
ordinal: 107000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `ConfirmationType.siteFailure` is declared and mapped to `AnnotationKind.siteFailure` (`lib/feedback/pending_confirmation.dart:14,18-23`) but `ConfirmationService.scan` (`lib/feedback/confirmation_service.dart:28-117`) never produces it, while `StubbornHighDetector` already computes `likelySiteIssue` (`lib/insights/care_detectors.dart:151`) — a wired-end-to-end confirmation type that can never appear.

**Reason for change.** The confirmation plumbing exists but is dead; wiring the detector in turns an existing signal into labelled training/annotation data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A site-failure branch in `ConfirmationService.scan` is fed by `StubbornHighDetector`, deduped against existing siteFailure annotations with a stable per-day id
- [ ] #2 Confirming writes the annotation
- [ ] #3 A unit test covers the branch
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a site-failure branch to `ConfirmationService.scan` fed by `StubbornHighDetector.likelySiteIssue`.
- Dedup against existing siteFailure annotations with a stable per-day id.
- Confirming writes the `AnnotationKind.siteFailure` annotation.
- Add a unit test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/feedback/confirmation_service.dart:28-117`)
- Effort: S
- Where: `lib/feedback/confirmation_service.dart`, `lib/insights/care_detectors.dart`
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
