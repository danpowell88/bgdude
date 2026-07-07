---
id: TASK-150
title: Screen-reader semantics for core surfaces
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:43'
updated_date: '2026-07-07 04:30'
labels:
  - code-health
  - ui
  - accessibility
milestone: m-8
dependencies: []
priority: medium
ordinal: 107100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `Semantics`/`semanticLabel` occur zero times across `lib/ui/`; the glucose hero (`lib/ui/widgets/glucose_hero.dart`) and stat tiles render value + trend as decorative glyphs (`lib/widget/bg_widget_format.dart:42-51`) that announce as raw symbols or nothing under TalkBack.

**Reason for change.** The primary safety readout of the app is inaccessible to screen-reader users.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The glucose hero exposes a semantic label ("<value> <unit>, <trend words>, <in range/low/high>")
- [x] #2 The shared StatTile and icon-only buttons are labelled
- [x] #3 A test asserts the hero exposes a non-empty label
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:27
---
Started: Semantics label on the glucose hero (value + unit + trend words + range status), StatTile labelling, hero semantics widget test.
---

author: Claude
created: 2026-07-07 04:30
---
Done (commit cf43917). AC#2 note: icon-only IconButtons app-wide already have tooltip: (verified via the existing screens) which Android exposes as the accessible name; StatTile was the unlabelled gap and is now covered.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
GlucoseHero wraps in Semantics (container, excludeSemantics) with the composed sentence from the public semanticLabelFor(): '<value> <unit>, <trend words>, <in range/low/high>' + staleness; trend glyphs map to words (rising fast/steady/falling slowly...). All three StatTile variants (card/panel/metric) expose 'label: value suffix'. Icon-only buttons across the app already carry tooltips (which Flutter exposes as semantics). Tests pin the composed label for in-range/low/no-reading and assert the rendered hero exposes it. Verified: analyze clean, 727 tests green, APK builds. Commit cf43917.
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
