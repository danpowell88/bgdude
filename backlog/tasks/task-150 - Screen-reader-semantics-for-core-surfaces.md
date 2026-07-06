---
id: TASK-150
title: Screen-reader semantics for core surfaces
status: To Do
assignee: []
created_date: '2026-07-06 08:43'
labels:
  - code-health
  - ui
  - accessibility
milestone: m-8
dependencies: []
priority: medium
ordinal: 150000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `Semantics`/`semanticLabel` occur zero times across `lib/ui/`; the glucose hero (`lib/ui/widgets/glucose_hero.dart`) and stat tiles render value + trend as decorative glyphs (`lib/widget/bg_widget_format.dart:42-51`) that announce as raw symbols or nothing under TalkBack.

**Reason for change.** The primary safety readout of the app is inaccessible to screen-reader users.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The glucose hero exposes a semantic label ("<value> <unit>, <trend words>, <in range/low/high>")
- [ ] #2 The shared StatTile and icon-only buttons are labelled
- [ ] #3 A test asserts the hero exposes a non-empty label
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a semantic label to the glucose hero composing value, unit, trend words, range status.
- Label the shared StatTile and icon-only buttons.
- Add a widget test asserting the hero exposes a non-empty semantic label.
- Verify: `flutter analyze` clean, `flutter test` green, spot-check with TalkBack on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ui/widgets/glucose_hero.dart`, `lib/widget/bg_widget_format.dart:42-51`)
- Effort: M
- Where: `lib/ui/widgets/glucose_hero.dart`, shared StatTile, icon-only buttons
- Related: TASK-107 (StatTile), TASK-98
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
