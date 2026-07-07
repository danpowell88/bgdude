---
id: TASK-228
title: Edge-to-edge readiness (targetSdk is already 37 — Android 15+ enforces it)
status: To Do
assignee: []
created_date: '2026-07-06 22:15'
updated_date: '2026-07-07 19:53'
labels:
  - code-health
  - ui
  - detail-needed
milestone: m-8
dependencies: []
priority: high
ordinal: 113260
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The app already targets SDK 37, so Android 15+ devices enforce edge-to-edge NOW, and grep finds zero inset/SystemUiMode/edge-to-edge handling anywhere in .dart/.kt/.xml — custom scaffolds (glucose hero, charts, bottom sheets, reports) may draw under system bars on current devices. Flutter 3.27 handles the mechanics but layouts must be inset-safe.

**Reason for change.** This is a live rendering defect risk on every Android 15+ device today, not a future migration item.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A visual pass on an API 35/36 emulator covers the main screens
- [ ] #2 SafeArea/inset fixes applied where content collides with system bars
- [ ] #3 An in-process test variant (device-config matrix ticket TASK-223) or golden covers one edge-to-edge regression
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Boot an API 35/36 emulator and do a visual pass across the main screens (glucose hero, charts, bottom sheets, reports, settings).
- Apply SafeArea/inset fixes wherever content collides with system bars.
- Add an in-process test variant (via TASK-223) or a golden covering one edge-to-edge regression.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: re-run the visual pass on the API 35/36 emulator after fixes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (version audit)
- Effort: M
- Where: custom scaffolds and screen layouts across `lib/`
- Related: TASK-96, TASK-150, TASK-98, TASK-223
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 19:53
---
detail-needed: AC#1 (visual pass on an API 35/36 emulator) and AC#3 (in-process test variant via TASK-223, which is itself still To Do, or a golden) cannot be completed in this session -- the only AVD here is Pixel_7_Pro at android-37.0 (no API 35/36 image), and the emulator VM-service WebSocket connection is broken here for ANY integration_test/flutter drive run regardless of API level (same pre-existing limitation as TASK-127/226/31/33). TASK-223 (device-config matrix) is a separate, not-yet-started ticket this one explicitly depends on for AC#3's automated path.

Made real progress on AC#2 via static analysis instead of a live visual pass (grep for showModalBottomSheet/DraggableScrollableSheet/Positioned across lib/ui, cross-checked against the 2 sheets that already wrap in SafeArea): found and fixed 2 real gaps --

- lib/ui/meal_library_screen.dart's _AddMealSheet only padded for viewInsets.bottom (keyboard), never the system bottom inset (gesture nav bar) -- wrapped in SafeArea, matching lib/ui/quick_log_sheet.dart's already-correct pattern.
- lib/ui/reports/glucose_report_screen.dart's _ClinicPrepSheet (a DraggableScrollableSheet) had the same gap on its Share PDF button / disclaimer text -- wrapped its ListView in SafeArea.

Checked lib/ui/barcode_scan_screen.dart's Positioned bottom overlay too (the only other Positioned-in-Stack site) -- it sits inside a normal Scaffold(appBar:, body:) without extendBody, so Scaffold's own default inset already protects it; no fix needed. Grepped for extendBodyBehindAppBar/resizeToAvoidBottomInset: false across lib/ -- zero hits, so the more common escape hatches for opting OUT of Scaffold's automatic inset handling aren't in use anywhere, which is a good sign the base Scaffold screens are already edge-to-edge-safe by default; the 2 custom bottom sheets above were the actual gaps.

This is a real but partial improvement, not a substitute for AC#1's actual visual pass -- there could be other collisions (chart legends, glucose hero) that only show up on a real device/emulator, which is exactly why AC#1/#3 stay open.

Pipeline: flutter analyze clean (also fixed an unrelated dormant curly_braces_in_flow_control_structures lint that dart format surfaced in meal_library_screen.dart), flutter test test/ 1034/1034 (unchanged, as expected for a UI-wrapper-only change), flutter build apk --debug succeeded. No native Kotlin, no user-guide update (invisible layout fix matching the existing pattern).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
