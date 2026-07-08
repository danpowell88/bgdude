---
id: TASK-283
title: '''Clarke error grid'' text not found on the Advanced screen (app_test.dart:315)'
status: To Do
assignee: []
created_date: '2026-07-08 00:16'
updated_date: '2026-07-08 00:16'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113252
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow: integration_test/app_test.dart's 'advanced/model internals screen renders sections' test expects exactly one 'Clarke error grid' text widget and finds zero. Could be a genuine missing-widget regression, a demo-data/timing gate (needs scored predictions that don't exist yet at this point in the simulated day), or a scroll-visibility issue distinct from the tap-miss class (findsOneWidget doesn't require visibility, only tree presence, so this is NOT the same bug as TASK-235/279's tap-miss pattern) -- needs investigation against lib/ui/advanced_screen.dart's actual render conditions for that section.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Root cause identified (missing widget vs. gated-on-data vs. something else)
- [ ] #2 Fixed or the gate documented as intentional, confirmed via the emulator workflow
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
<!-- DOD:END -->
