---
id: TASK-292
title: >-
  Emulator suite aborts on the first failing file, hiding signal for every file
  after it
status: Done
assignee:
  - Claude
created_date: '2026-07-08 03:26'
updated_date: '2026-07-08 03:29'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 113266
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
tools/run_functional_integration_tests.sh (and .ps1) use set -euo pipefail with a plain loop calling flutter test per file -- the first non-zero exit (e.g. chaos_navigation_test.dart's TASK-291 timeout failure) aborts the whole script immediately. Confirmed by dispatch 28914262834's log: it stopped right after chaos_navigation_test.dart's failure, never running db_recovery_screen_test.dart (TASK-252 AC#3), features_flows_test.dart, features_protocol_explorer_test.dart, features_reports_test.dart, or features_settings_test.dart (TASK-279 AC#2) at all. One broken file currently masks pass/fail signal for everything scheduled after it in the list.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every file in the list runs regardless of an earlier file's failure
- [x] #2 The script's own exit code is non-zero if ANY file failed, and it prints a clear per-file summary (which passed, which failed) so CI failure is still visible
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: self-filed while investigating TASK-291/252/279 2026-07-08
- Files: tools/run_functional_integration_tests.sh, tools/run_functional_integration_tests.ps1 (keep in sync per their own header comment)
- Related: TASK-288 (test pipeline resilience) is broader/different scope (network/hermetic/retries) -- this is specifically about one file's failure blocking every later file's signal
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:26
---
Started: making both scripts run every file regardless of earlier failures, tracking pass/fail per file, and exiting non-zero overall if any failed.
---

author: Claude
created: 2026-07-08 03:29
---
Fixed both scripts:

tools/run_functional_integration_tests.sh: wrapped each flutter test call in an if/else (the one bash context where set -e's errexit doesn't trigger) to keep looping through every file, accumulating PASSED/FAILED arrays, printing a PASS/FAIL summary, and exiting 1 if anything failed. Smoke-tested with a fake flutter shim on PATH that fails only for chaos_navigation_test.dart -- confirmed all 7 files ran (not just the first 2), the summary correctly listed 6 PASS + 1 FAIL, and the script exited 1.

tools/run_functional_integration_tests.ps1: PowerShell's  doesn't stop execution on a native command's non-zero exit code by default (that only affects PowerShell's own error stream) -- so the OLD script wasn't actually aborting on a failure, it was silently continuing AND still printing 'All functional integration tests passed' regardless, a worse bug (false-positive green) than the bash version's true abort. Added explicit  checks per file, the same PASS/FAIL summary, and exit 1 on any failure.

Verified: flutter analyze clean (shell/PS1-only change, no Dart/Kotlin touched so test/build/native pipeline unaffected). No user-guide update (dev tooling, not user-visible).
---
<!-- COMMENTS:END -->

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
<!-- DOD:END -->
