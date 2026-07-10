---
id: TASK-155
title: Overlay detected events onto report and prediction charts
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 08:44'
updated_date: '2026-07-10 11:20'
labels:
  - feature
  - ui
  - insights
milestone: m-7
dependencies: []
priority: medium
ordinal: 702500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `EventBuilder` (`lib/timeline/event_builder.dart`) already produces timestamped DayEvents (meals, boluses, unannounced rises, compression lows) and annotations are stored, but charts (`lib/ui/widgets/prediction_chart.dart`, glucose report) draw glucose only — the user cannot see why a curve moved.

**Value.** Event markers on the curve connect cause to effect at a glance and give Explain-this-reading a natural entry point.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An event-marker layer (icons at x=time) exists on the glucose report and on-board forecast charts, reusing EventBuilder output
- [ ] #2 Tapping a marker opens Explain-this-reading
- [ ] #3 An integration test covers the overlay
- [ ] #4 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add an event-marker layer (icons at x=time) reusing EventBuilder output.
- Apply it to the glucose report chart and the on-board forecast charts.
- Wire marker taps to Explain-this-reading.
- Add an integration test.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green, integration test on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/timeline/event_builder.dart`, `lib/ui/widgets/prediction_chart.dart`)
- Effort: M
- Where: `lib/ui/widgets/prediction_chart.dart`, glucose report chart, `doc/user-guide.html`
- Related: TASK-107 (chart scaffolding)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 11:20
---
branch: task-155
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
