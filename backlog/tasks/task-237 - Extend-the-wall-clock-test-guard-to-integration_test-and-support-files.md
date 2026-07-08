---
id: TASK-237
title: Extend the wall-clock test guard to integration_test/ and support files
status: Done
assignee:
  - Claude
created_date: '2026-07-07 07:48'
updated_date: '2026-07-08 02:28'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: low
ordinal: 113246
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The new guard (`test/support/no_wall_clock_guard_test.dart:19-27`, d8e49f3) scans only `test/**/*_test.dart` — it skips `integration_test/` entirely (where wall-clock coupling is worst: demo mode advances on real time) and skips non-`_test` support/fixture files, where one `DateTime.now()` would couple every consumer.

**Reason for change.** The guard exists to stop new relative-time tests landing silently; its blind spots are exactly the highest-risk locations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Guard walks both roots and all .dart files, keeping the `now-ok` escape hatch
- [x] #2 Existing legitimate uses annotated or fixed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extend the directory walk; triage any new hits.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #3 (finding 3)
- Effort: S
- Where: test/support/no_wall_clock_guard_test.dart
- Related: TASK-170 (introduced), TASK-220
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:24
---
Started: extending test/support/no_wall_clock_guard_test.dart's directory walk to cover integration_test/ and non-_test support/fixture files, keeping the now-ok escape hatch.
---

author: Claude
created: 2026-07-08 02:28
---
Fixed: extended test/support/no_wall_clock_guard_test.dart to walk both test/ and integration_test/ roots and every .dart file in each (not just *_test.dart), keeping the now-ok escape hatch and the guard's own self-exclusion.

AC#2: grepped both expanded scopes (integration_test/*.dart, test/support/*.dart, test/flutter_test_config.dart) for DateTime.now() before the change -- zero pre-existing hits, so there was nothing to annotate/fix; the widened net starts clean.

Rigor check: temporarily added an unguarded 'final _tempBug = DateTime.now();' to integration_test/harness.dart (previously invisible to the guard), reran -- failed with the exact expected offender line -- then reverted (git diff confirmed clean).

Verified: flutter analyze clean, flutter test --coverage test/ green (1150 tests). No Dart production/native code changed beyond the guard test itself, so build/apk/native pipeline unaffected.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
