---
id: TASK-125
title: Handle failures in the app-root snapshot chain
status: To Do
assignee: []
created_date: '2026-07-06 08:37'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 100500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/app.dart:28-38` chains `ingestSnapshot(...).then((_) => onSnapshot())` with no catch — an ingest failure silently skips alert evaluation — and Nightscout `uploadEntries`/`uploadDeviceStatus` are launched unawaited with no error capture (unhandled async errors).

**Reason for change.** A single ingest exception currently disables the entire alert pipeline for that snapshot with no trace; the safety chain must fail loudly and keep alerting.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The ingest-to-alert chain has logged error handling and alert evaluation still runs (or the skip is logged loudly)
- [ ] #2 Network pushes are wrapped with `unawaited(...)` plus internal logged handling
- [ ] #3 A test simulating ingest failure passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add error handling around `ingestSnapshot(...).then(...)` so `onSnapshot()` still runs (or the skip is logged loudly).
- Wrap Nightscout `uploadEntries`/`uploadDeviceStatus` with `unawaited(...)` and internal logged catch.
- Add a test simulating ingest failure.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/app.dart:28-38`)
- Effort: S
- Where: `lib/app.dart`
- Related: TASK-38
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
