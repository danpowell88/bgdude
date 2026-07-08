---
id: TASK-301
title: >-
  Harden the sharded CI so it cannot mask a native-test flake or silently drop a
  test
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 07:27'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 198000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Verifying the TASK-288/297 CI work surfaced four test-signal-integrity gaps in .github/workflows/ci.yml. Two matter: (1) the native-tests retry (nick-fields/retry, max_attempts 2) wraps the whole command including cd android and ./gradlew :app:testDebugUnitTest --no-daemon (ci.yml:331-344), so the actual Kotlin TEST execution is retried, not just Gradle dependency resolution -- an intermittent native-test failure passes on attempt 2 and goes green, masking the flake. These native tests are the read-only-pump charter guard and the mU-to-U conversion guard, so silently masking an intermittent failure there is the highest-value masked-failure risk. (2) The shard split is a hardcoded case list of directories (ci.yml:150-155) with no guard that the union equals the actual set of test/ subdirs; the moment a *_test.dart lands under an unlisted dir (e.g. the already-omitted test/contracts/, or a new test/security/) it is silently never run and its coverage never counted -- analyze/test stay green on an untested feature. Two lower-severity items ride along: apk-build retries flutter build apk --debug which includes compilation (ci.yml:264-270), so a nondeterministic build failure could be masked; and lcov --ignore-errors includes empty (ci.yml:181), suppressing the one signal that a shard contributed no coverage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The native-tests retry wraps ONLY the network-dependent Gradle dependency-resolution phase (e.g. a separate ./gradlew dependencies/resolve step), not the test execution -- an intermittent native-test failure fails the build
- [ ] #2 A CI guard asserts the union of the shard directory lists equals the actual set of test/ subdirs containing a *_test.dart (fail the build if a dir is unlisted), OR sharding is done by flutter's --total-shards/--shard-index so no dir can be missed
- [ ] #3 apk-build retry is scoped to dependency resolution, not the compile, or the retry is removed there
- [ ] #4 lcov merge does not silently tolerate an empty shard tracefile (drop the empty suppression or assert each shard contributed coverage)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying TASK-288 (5e39036) and TASK-297 (e14c6bd)
- File: .github/workflows/ci.yml native-tests retry :331-344, shard case list :150-155, apk retry :264-270, lcov merge :181
- The coverage gate itself is correct (post-merge, unioned, database.g.dart excluded, >=65) and the build_runner cache cannot serve stale codegen -- those were verified fine; this ticket is only the masking/drop gaps
<!-- SECTION:NOTES:END -->

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
