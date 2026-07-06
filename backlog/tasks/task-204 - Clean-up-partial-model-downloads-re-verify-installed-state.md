---
id: TASK-204
title: Clean up partial model downloads; re-verify installed state
status: To Do
assignee: []
created_date: '2026-07-06 21:10'
labels:
  - code-health
  - "\U0001F9E0 llm"
milestone: m-8
dependencies: []
priority: low
ordinal: 111800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/panel_model_manager.dart:29-40` delegates the ~0.5 GB download to flutter_gemma with no partial-file handling; `_restore` (`lib/providers.dart:216-221`) trusts `isModelInstalled` blindly, and the `downloading` flag only resets via catch — not on process death.

**Reason for change.** A process death mid-download can leave a partial file that passes the installed check and then fails at load.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A persisted in-flight-download marker exists; on restore with the marker set, re-verify or delete before marking installed
- [ ] #2 Load failure falls back to parser-only and clears installed
- [ ] #3 Test with a truncated model file
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Persist an in-flight-download marker before starting the download and clear it on verified completion
- On restore with the marker set, re-verify the model (or delete the partial file) before marking installed
- Make load failure fall back to parser-only and clear the installed state
- Add a test using a truncated model file
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 9)
- Effort: S
- Where: `lib/panel_model_manager.dart:29-40`, `lib/providers.dart:216-221`
- Related: TASK-88 (integrity/gating), TASK-16
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
