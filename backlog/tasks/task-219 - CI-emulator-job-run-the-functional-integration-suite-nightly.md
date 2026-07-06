---
id: TASK-219
title: 'CI emulator job: run the functional integration suite nightly'
status: To Do
assignee: []
created_date: '2026-07-06 22:12'
labels:
  - testing
  - infra
milestone: m-8
dependencies: []
priority: medium
ordinal: 113300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** CI currently runs unit tests only; the ~38 functional on-device tests (`integration_test/app_test.dart`, `features_flows_test.dart`, `features_settings_test.dart`, `features_reports_test.dart`, `features_protocol_explorer_test.dart`) run only when someone remembers to run them locally. GitHub ubuntu runners have KVM, so `reactivecircus/android-emulator-runner@v2` works; AVD snapshot caching keyed on API+arch keeps a cached boot at ~3-4 min, and the full functional suite is ~6-8 min, so roughly 12-15 min per configuration.

- `screenshots_test.dart` and `walkthrough_test.dart` need `flutter drive` and stay excluded.
- `nutrition_ocr_accuracy_test.dart` needs network + ~5 min and stays excluded.
- This resolves the open TASK-159 decision (scheduled emulator job vs manual-only): nightly `schedule` + `workflow_dispatch`, NOT per-push blocking, keeping the PR pipeline at ~12 min.

**Reason for change.** The on-device suite is the only automated coverage of real screen flows; without a scheduled CI job it silently rots, and regressions are found late and manually.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A nightly + manually-dispatchable workflow boots a cached AVD and runs the named functional integration test files
- [ ] #2 Failures are visible (badge or notification)
- [ ] #3 The run list is defined in one place shared with local runs
- [ ] #4 The TASK-159 decision (nightly schedule + workflow_dispatch, not per-push blocking) is documented on both tasks
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a `.github/workflows/emulator-tests.yml` with `schedule` (nightly) + `workflow_dispatch` triggers.
- Use `reactivecircus/android-emulator-runner@v2` with AVD snapshot caching keyed on API level + arch.
- Reuse the Gradle cache setup from the main CI workflow.
- Define the functional test file list in one shared place (script under `tools/`) used by both CI and local runs.
- Surface failures via workflow badge or notification.
- Document the decision on this task and TASK-159.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: dispatch the workflow manually once and confirm the emulator job passes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (CI/emulator audit)
- Effort: S-M
- Where: `.github/workflows/`, `tools/`
- Related: TASK-159 (resolves its integration policy), TASK-218 (reuse Gradle cache), TASK-98
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
