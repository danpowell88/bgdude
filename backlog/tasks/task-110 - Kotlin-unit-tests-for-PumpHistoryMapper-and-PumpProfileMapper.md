---
id: TASK-110
title: Kotlin unit tests for PumpHistoryMapper and PumpProfileMapper
status: To Do
assignee: []
created_date: '2026-07-06 04:54'
labels:
  - code-health
  - testing
  - native
  - pump
dependencies: []
priority: medium
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** android/app/src/test has only three test classes (MutableSnapshot, ProtocolProbe, PumpResponseMapper). Two pure mappers are untested:

- `PumpHistoryMapper.kt` — Tandem-epoch to Unix-ms conversion (`TANDEM_EPOCH_MS`, line 24). Note the divergence worth pinning: `CgmDataGxHistoryLog` uses `message.timestamp` (line 33) while every other type uses `log.pumpTimeSec` (line 77).
- `PumpProfileMapper.kt` — milli-unit (x1000) conversions for basal rate and carb ratio (lines 12-15) and the segment-accumulation `complete` flag.

**Reason for change.** These run on-device with no hardware validation; a wrong epoch offset or a missing /1000 silently corrupts imported history and therapy settings. JUnit is already wired (build.gradle:88).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PumpHistoryMapperTest: known Tandem-seconds map to expected Unix-ms for each mapped type; unmapped types return null; the CgmDataGx timestamp-field divergence is pinned by a test
- [ ] #2 PumpProfileMapperTest: fixture segments produce expected basal/ISF/CR/target JSON; complete flag only set when all segments present
- [ ] #3 cd android && ./gradlew :app:testDebugUnitTest green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Verify pumpx2 response-class constructors via javap on the cached jar before writing fixtures (see memory pumpx2-native-verification).
- Build minimal history-log/profile fixtures; assert mapped output field-by-field.
- Run the gradle unit-test task.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 3)
- Effort: S–M
- Where: android/app/src/main/kotlin/com/bgdude/app/pump/PumpHistoryMapper.kt, PumpProfileMapper.kt
<!-- SECTION:NOTES:END -->
