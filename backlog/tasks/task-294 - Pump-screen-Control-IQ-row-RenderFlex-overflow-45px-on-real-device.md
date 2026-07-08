---
id: TASK-294
title: Pump screen Control-IQ row RenderFlex overflow (45px) on real device
status: Blocked
assignee:
  - Claude
created_date: '2026-07-08 04:15'
updated_date: '2026-07-08 04:16'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113270
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow (dispatch 28915351919, features_settings_test.dart): 'Pump screen shows live status incl. Control-IQ' and 'changing units to mg/dL propagates to the Pump screen' both failed with 'A RenderFlex overflowed by 45 pixels on the right' at lib/ui/pump_screen.dart:145, the shared _Row(label, value) widget used throughout the pump status card. The Control-IQ row's value (_controlIqLabel, e.g. 'Active . Sleep') is long enough to overflow the row's fixed ~248px width on this device/font-scale combination -- app_test.dart's scripted checks never hit this specific row's actual rendered width.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The pump status card's rows no longer overflow for a long value string (e.g. Control-IQ's mode-annotated label)
- [ ] #2 Confirmed via the emulator workflow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: TASK-219 emulator dispatch 28915351919, 2026-07-08
- File: lib/ui/pump_screen.dart:145 (_Row widget)
- Fixed: wrapped the value Text in Flexible + TextOverflow.ellipsis (matching the TASK-280/281 pattern), label stays un-truncated
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 04:16
---
Started+fixed: wrapped _Row's value Text in Flexible(TextOverflow.ellipsis, textAlign: end) so a long value like Control-IQ's mode-annotated label ellipsizes instead of overflowing the row.
---

author: Claude
created: 2026-07-08 04:16
---
AC#1 done (code fix). AC#2 (confirmed via emulator workflow) staying Blocked -- needs one more dispatch to verify, which I'm not looping on indefinitely this session given the standing instruction not to chase 100% green forever. Pipeline verified locally: flutter analyze clean, flutter test --coverage green (1161, 67.59%), flutter build apk --debug succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
