---
id: TASK-149
title: Produce siteFailure confirmations from StubbornHighDetector
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:42'
updated_date: '2026-07-07 04:26'
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
- [x] #1 A site-failure branch in `ConfirmationService.scan` is fed by `StubbornHighDetector`, deduped against existing siteFailure annotations with a stable per-day id
- [x] #2 Confirming writes the annotation
- [x] #3 A unit test covers the branch
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:23
---
Started: site-failure branch in ConfirmationService.scan fed by StubbornHighDetector.likelySiteIssue with a stable per-day id, deduped against existing siteFailure annotations; confirm path already maps to AnnotationKind.siteFailure; unit test added.
---

author: Claude
created: 2026-07-07 04:26
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
scan() gained a siteAgeHours param (provider feeds it from deviceStateProvider); a StubbornHighAlert with likelySiteIssue queues ConfirmationType.siteFailure with a day-stable start (same id across rescans), deduped via _coveredBy against AnnotationKind.siteFailure. Confirming already writes the annotation through suggestedKind/confirmPending. Fixed 0.7 confidence documented as rule-based. 3 tests + guide sentence. Verified: analyze clean, 725 tests green, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
