---
id: TASK-155
title: Overlay detected events onto report and prediction charts
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-06 08:44'
updated_date: '2026-07-10 14:03'
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
- [x] #1 An event-marker layer (icons at x=time) exists on the glucose report and on-board forecast charts, reusing EventBuilder output
- [x] #2 Tapping a marker opens Explain-this-reading
- [x] #3 An integration test covers the overlay
- [x] #4 The user guide is updated
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

author: Claude
created: 2026-07-10 11:53
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-155 (commit 8614110).
created: 2026-07-10 11:54
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-155 (commit 9f4d256).

New lib/ui/widgets/event_marker_bar.dart: a tappable icon row aligned to a chart's own x-domain, showing DayEvent.explainable markers (highs/lows/detected rises/compression lows), tap -> Explain-this-reading via a new shared explainDayEvent() (extracted from TimelineEventCard, which now calls it too).

Wired into PredictionChart (Today + Predict tabs, x=minutes-from-now, reuses dayEventsProvider) and the Glucose report AGP chart (x=hour-of-day; only today's events since EventBuilder is per-day, captioned accordingly). OnBoardForecastChart deliberately skipped -- its x-domain starts at 0 (now) and only extends forward, so a past event can never land on it.

Rigor-checked a real bug: a Stack with only Positioned children collapses to zero width under a loose constraint (markers painted via Clip.none but were untappable) -- fixed by pinning the Stack to the full plot width; reverted the fix and confirmed the new widget test fails, then restored it.

Tests: unit tests for EventMarkerBar, a deterministic PredictionChart widget test (fixed demo clock puts the simulated day's ~03:10 compression low inside the chart's -150..0 history window), an integration test (same fixed-clock technique) + an AGP caption check. flutter analyze clean, flutter test --coverage green (1371 tests), coverage 68.52% (floor 65%), flutter build apk --debug succeeded. doc/user-guide.html updated (Today tab, Predict tab, Glucose report row).
---

author: Claude
created: 2026-07-10 11:53
---
friction:tooling — `dart run` on this package crashes (FFI/kernel transform exception) even for Flutter-independent files, so a quick pure-Dart probe script isn't viable here; had to write throwaway `flutter test` files instead (works, just slower). friction:code — a Stack with only Positioned children collapses to zero width under a loose parent constraint: it still PAINTS children outside its bounds via Clip.none, but hit-testing silently fails since RenderBox checks the parent's own size before testing children — caught only because the new widget test's tap() emitted a hit-test-miss warning; worth grepping for other Positioned-only Stacks in lib/ui/ if similar overlay patterns get reused.
friction:tooling -- `dart run` on this package crashes (FFI/kernel transform exception) even for Flutter-independent files, so a quick pure-Dart probe script isn't viable here; had to write throwaway flutter test files instead (works, just slower). friction:code -- a Stack with only Positioned children collapses to zero width under a loose parent constraint: it still PAINTS children outside its bounds via Clip.none, but hit-testing silently fails since RenderBox checks the parent's own size before testing children -- caught only because the new widget test's tap() emitted a hit-test-miss warning; worth grepping for other Positioned-only Stacks in lib/ui/ if similar overlay patterns get reused.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
