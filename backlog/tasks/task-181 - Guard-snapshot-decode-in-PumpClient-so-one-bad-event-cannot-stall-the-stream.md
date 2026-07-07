---
id: TASK-181
title: Guard snapshot decode in PumpClient so one bad event cannot stall the stream
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 09:18'
updated_date: '2026-07-07 07:46'
labels:
  - code-health
  - pump
milestone: m-8
dependencies: []
priority: medium
ordinal: 108200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/pump/pump_client.dart:87-91` runs `jsonDecode` + `PumpSnapshot.fromJson` inside the stream `onData` with no try/catch; the `onError` handler (line 64) catches stream errors only, so a malformed snapshot throws an uncaught zone error and the reading is dropped — a recurring shape quietly stops live updates.

**Reason for change.** One malformed event should cost one reading, not the live stream.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decode is wrapped: the error is logged, the event skipped, and the stream stays subscribed
- [ ] #2 Test: a malformed snapshot event → no throw, the next good event processes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wrap `jsonDecode` + `PumpSnapshot.fromJson` in try/catch inside `onData`; log and skip on failure.
- Add a test feeding a malformed event followed by a good one, asserting no throw and the good snapshot processes.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 7)
- Effort: S
- Where: `lib/pump/pump_client.dart`
- Related: TASK-120 (versioning reduces the cause; this handles it)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 07:46
---
Started: guard the snapshot decode in the event stream (log + skip, stay subscribed); malformed-then-good event test.
---
<!-- COMMENTS:END -->

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
