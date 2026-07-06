---
id: TASK-162
title: 'FPU extended-bolus duration: use the published Pankowska table'
status: To Do
assignee: []
created_date: '2026-07-06 09:14'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - dosing-math
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/analytics/bolus_advisor.dart:178` computes extend-hours as `(fpu.ceil()+2).clamp(3, 8)`, giving 4 FPU→6 h and 5 FPU→7 h; the published Pankowska/Warsaw table is 1→3 h, 2→4 h, 3→5 h, and ≥4 FPU→8 h — the 4-5 FPU range is under-extended, risking stacking then rebound for large fatty meals. The kcal math `(fat*9+protein*4)/100` and 1 FPU ≈ 10 g carb-equivalent are verified correct.

**Reason for change.** Large fatty meals in the 4-5 FPU range get an extended bolus that ends 1-2 hours too early relative to the published clinical table.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Step table matches the published values (1→3, 2→4, 3→5, >=4→8)
- [ ] #2 Tests pin 3 FPU→5 h and 4 FPU→8 h
- [ ] #3 User guide FPU section updated if it states durations
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Replace the `(fpu.ceil()+2).clamp(3, 8)` expression with the published step table (1→3, 2→4, 3→5, >=4→8).
- Add tests pinning 3 FPU→5 h and 4 FPU→8 h.
- Check `doc/user-guide.html` FPU section for stated durations and update if present.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (accuracy finding 2)
- Effort: S
- Where: `lib/analytics/bolus_advisor.dart`, `test/bolus_advisor_test.dart`, `doc/user-guide.html`
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
