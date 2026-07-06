---
id: TASK-228
title: Edge-to-edge readiness (targetSdk is already 37 — Android 15+ enforces it)
status: To Do
assignee: []
created_date: '2026-07-06 22:15'
labels:
  - code-health
  - ui
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
