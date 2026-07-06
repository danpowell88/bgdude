---
id: TASK-165
title: Extract and regression-pin the JPAKE pairing-scheme decision
status: To Do
assignee: []
created_date: '2026-07-06 09:14'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - native
  - pump
  - testing
milestone: m-8
dependencies: []
priority: high
ordinal: 102700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Commit d18d72e fixed two bugs that blocked every JPAKE (6-digit) pump: the pairing scheme defaulted to the 16-char challenge, and `submitPairingCode` skipped `pair()` when `CentralChallenge` was null. The logic lives in `PumpCommHandler.kt`/`PumpBridge.kt` and no Kotlin test references pairing or challenge selection.

**Reason for change.** A refactor can silently re-break the core pairing feature for a whole pump generation; the decision needs to be a pure, JVM-testable function with regression pins.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The scheme→challenge decision is extracted as a pure function `(scheme, code) → PairRequest` with no BLE deps
- [ ] #2 JVM tests pin: JPAKE/6-digit → no central challenge AND `pair()` still invoked; long-code scheme → 16-char challenge
- [ ] #3 `gradlew :app:testDebugUnitTest` green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extract the pairing scheme→challenge selection from `PumpCommHandler.kt`/`PumpBridge.kt` into a pure function `(scheme, code) → PairRequest`.
- Add JVM tests pinning the JPAKE/6-digit path (no central challenge, `pair()` invoked) and the long-code path (16-char challenge).
- Verify pumpx2 APIs via `javap` on the cached jar before writing.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 3)
- Effort: M
- Where: `android/app/src/main/kotlin/.../PumpCommHandler.kt`, `PumpBridge.kt`, `android/app/src/test/`
- Related: TASK-114 (same file — coordinate), TASK-33
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
