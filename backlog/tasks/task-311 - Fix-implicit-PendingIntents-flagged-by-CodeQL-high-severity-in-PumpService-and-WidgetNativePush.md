---
id: TASK-311
title: >-
  Fix implicit PendingIntents flagged by CodeQL (high severity) in PumpService
  and WidgetNativePush
status: To Do
assignee: []
created_date: '2026-07-10 13:43'
labels:
  - security
milestone: m-8
dependencies: []
priority: high
ordinal: 110800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CodeQL's first java-kotlin scan (decision-11) found 3 open high-severity alerts, rule `java/android/implicit-pendingintents`: a PendingIntent wrapping an implicit Intent can be hijacked — another app can intercept or redirect it, a real concern on the process hosting the pump BLE connection.

Sites (alert locations at scan time, commit 4eaabc1):

- `android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt:221`
- `android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt:299`
- `android/app/src/main/kotlin/com/bgdude/app/widget/WidgetNativePush.kt:77`

Fix: make each wrapped Intent explicit (`setClass`/`setComponent`/`setPackage` to our own package) rather than suppressing the alert. These alerts sit at the ruleset blocking threshold (high_or_higher), so any PR that re-touches this code without fixing them risks tripping the merge gate.

- Source: CodeQL alerts on main, 2026-07-10 (Security tab > Code scanning).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All three `java/android/implicit-pendingintents` alerts are fixed by making the intents explicit (not dismissed/suppressed), and the CodeQL PR check reports no high+ alerts on the branch
- [ ] #2 Per the sweep-the-whole-surface rule: grep android/ for every other PendingIntent.get* site and confirm each wraps an explicit Intent (or document why not)
- [ ] #3 A native unit test asserts the affected intents are explicit (component/package set) so a regression to implicit fails the suite
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
- [ ] #10 Reviewed by a different agent than the implementer -- a reviewed-by comment is present and the task passed through Review before Done
<!-- DOD:END -->
