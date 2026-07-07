---
id: TASK-125
title: Handle failures in the app-root snapshot chain
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:37'
updated_date: '2026-07-06 21:55'
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
- [x] #1 The ingest-to-alert chain has logged error handling and alert evaluation still runs (or the skip is logged loudly)
- [x] #2 Network pushes are wrapped with `unawaited(...)` plus internal logged handling
- [x] #3 A test simulating ingest failure passes
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 21:51
---
Started: wrap the app-root ingest->alert chain with logged error handling so onSnapshot still runs on ingest failure; unawaited(+logged catch) for the Nightscout pushes; add an ingest-failure test.
---

author: Claude
created: 2026-07-06 21:55
---
Done (commit 8689179). DoD 5-7 vacuously met (no native change, not user-visible, no screen/flow change).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added lib/state/snapshot_chain.dart: ingestThenEvaluateAlerts() logs an ingest failure and still runs alert evaluation (alerting on the previous day state beats not alerting); alert-evaluation failures are logged, not propagated. app.dart wires the chain via unawaited(...) and wraps the Nightscout uploadEntries/uploadDeviceStatus calls in unawaitedLogged(...) (the client's _postJson already never throws, but mapping before it could raise an unhandled async error). 5 tests in test/snapshot_chain_test.dart including the ingest-failure simulation. Verified: analyze clean, 614 tests green, debug APK builds. Commit 8689179.
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
