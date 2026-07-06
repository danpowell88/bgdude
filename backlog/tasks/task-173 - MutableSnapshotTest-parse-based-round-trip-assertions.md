---
id: TASK-173
title: 'MutableSnapshotTest: parse-based round-trip assertions'
status: To Do
assignee: []
created_date: '2026-07-06 09:16'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - native
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 107800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `MutableSnapshotTest.kt:40-42` verifies the hand-rolled JSON serializer only by substring presence/absence (`assertFalse(json.contains("cgmMgdl"))`) — an escaping/comma bug that keeps the substrings intact produces invalid JSON that only fails at runtime on-device.

**Reason for change.** The serializer feeds the Dart snapshot pipeline; its tests must prove the output is valid, decodable JSON, not that substrings appear.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tests round-trip the serialized output through a real JSON parser and assert on decoded fields
- [ ] #2 One negative test asserts an unset field key is absent after decode
- [ ] #3 Gradle tests green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Rewrite `MutableSnapshotTest` assertions to decode the JSON with a real parser and assert on decoded field values.
- Add a negative test: an unset field is absent as a key in the decoded map.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 11)
- Effort: S
- Where: `android/app/src/test/.../MutableSnapshotTest.kt`
- Related: TASK-120 (schema versioning + golden fixture)
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
