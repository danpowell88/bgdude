---
id: TASK-312
title: >-
  Disable Android auto-backup of app data (CodeQL java/android/backup-enabled,
  high)
status: To Do
assignee: []
created_date: '2026-07-10 14:11'
labels:
  - security
milestone: m-8
dependencies: []
priority: high
ordinal: 110900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CodeQL (security-and-quality suite, decision-11) flags `android:allowBackup` as enabled (`java/android/backup-enabled`, security severity high). With auto-backup on, app data — a diabetes app's glucose/pump history database — is backed up to the user's Google account cloud storage, an avoidable data-exposure surface for health data.

- Fix: set `android:allowBackup="false"` (and `android:fullBackupContent"/`dataExtractionRules` accordingly for API 31+) in `android/app/src/main/AndroidManifest.xml`.
- Source: CodeQL alerts on main, 2026-07-11.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `android:allowBackup" is false (with matching dataExtractionRules for API 31+) and the CodeQL alert no longer reports on the branch
- [ ] #2 App still installs/runs normally (verify pipeline + APK build green)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
- [ ] #10 Reviewed by a different agent than the implementer -- a reviewed-by comment is present and the PR was merged when the task reached Reviewed
- [ ] #11 Done only after Summer verified the task's human-verification batch (decision-12) -- agents never set Done
<!-- DOD:END -->
