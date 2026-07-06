---
id: TASK-225
title: Camera OCR panel-scan e2e via the emulator virtual-scene camera
status: To Do
assignee: []
created_date: '2026-07-06 22:14'
labels:
  - testing
  - "\U0001F9E0 llm"
milestone: m-8
dependencies:
  - TASK-219
priority: low
ordinal: 113900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `nutrition_ocr_accuracy_test.dart` OCRs downloaded bytes, but the camera capture path (`barcode_scan_screen.dart`, image_picker -> scan flow) is untested on-device. The emulator virtual-scene camera can present a fixed nutrition label image to the camera feed.

**Reason for change.** The capture-to-parse pipeline is the part users actually exercise; a virtual-scene (or picker-override) e2e closes the gap between byte-level OCR accuracy tests and the real scan flow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The AVD is configured with a virtual-scene nutrition label (or a picker override is used)
- [ ] #2 Driving Meals -> scan lands parsed carbs in the meal form
- [ ] #3 The barcode happy path is covered
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Configure the AVD virtual-scene camera with a fixed nutrition label image (or add a test-only image_picker override).
- Add an integration test driving Meals -> scan and asserting parsed carbs land in the meal form.
- Add a barcode happy-path case.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: run the new test on an emulator (`flutter test integration_test/<file>.dart -d emulator-5554`).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (emulator audit)
- Effort: S-M
- Where: `barcode_scan_screen.dart`, `integration_test/`, AVD config in the CI emulator workflow
- Related: TASK-27, TASK-85, TASK-89
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
