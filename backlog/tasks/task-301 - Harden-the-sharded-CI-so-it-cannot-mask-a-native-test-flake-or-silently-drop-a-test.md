---
id: TASK-301
title: >-
  Harden the sharded CI so it cannot mask a native-test flake or silently drop a
  test
status: Done
assignee:
  - Claude
created_date: '2026-07-08 07:27'
updated_date: '2026-07-08 07:52'
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
- [x] #1 The native-tests retry wraps ONLY the network-dependent Gradle dependency-resolution phase (e.g. a separate ./gradlew dependencies/resolve step), not the test execution -- an intermittent native-test failure fails the build
- [x] #2 A CI guard asserts the union of the shard directory lists equals the actual set of test/ subdirs containing a *_test.dart (fail the build if a dir is unlisted), OR sharding is done by flutter's --total-shards/--shard-index so no dir can be missed
- [x] #3 apk-build retry is scoped to dependency resolution, not the compile, or the retry is removed there
- [x] #4 lcov merge does not silently tolerate an empty shard tracefile (drop the empty suppression or assert each shard contributed coverage)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying TASK-288 (5e39036) and TASK-297 (e14c6bd)
- File: .github/workflows/ci.yml native-tests retry :331-344, shard case list :150-155, apk retry :264-270, lcov merge :181
- The coverage gate itself is correct (post-merge, unioned, database.g.dart excluded, >=65) and the build_runner cache cannot serve stale codegen -- those were verified fine; this ticket is only the masking/drop gaps
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 07:43
---
Started: this is the concurrent sessions review of my own TASK-288/297 CI work -- all 4 findings are legitimate. Plan: AC#1/#3 split the network-dependent phase (Gradle/Maven resolution) from the phase whose failure must actually gate the build (Kotlin test execution, Dart/Kotlin compilation) so a genuine flake/bug cannot be masked by a blind retry of the whole command. For native-tests specifically: local.properties writing becomes its own step; a new retry-wrapped, continue-on-error warm-up step runs one existing Robolectric test class first (confirmed all 14 Robolectric test classes uniformly use @Config(sdk=[34]), so any one of them exercises the same SDK-jar fetch path -- Robolectric fetches its android-all-instrumented jar via its own resolver at TEST RUNTIME on first use, which is NOT covered by gradle/actions/setup-gradle caching since that only covers ~/.gradle, not the Maven-style path Robolectric uses -- this is the real network dependency inside what used to be one retried step); the real gating test run is a separate, unretried step. For apk-build: taking AC#3s simpler sanctioned alternative (remove the retry rather than trying to cleanly split Gradle-Android dependency resolution from compilation, which has no equally clean single-purpose Gradle task to isolate it safely) -- the already-retried pub get step catches the large majority of transient blips; a rare Maven/JitPack resolution failure during the actual Android build becomes a real, visible failure again, matching pre-TASK-288 behavior for this one step. AC#2: switching the test job from a hand-maintained directory-list case statement to flutter tests native --total-shards/--shard-index sharding, which auto-discovers every test file under test/ -- verified locally all 4 shards sum to exactly 1314 (the full suite), so nothing can ever be silently unlisted again. AC#4: drop empty from lcov --ignore-errors so a shard that contributed zero coverage becomes a visible merge error instead of being silently tolerated.
---

author: Claude
created: 2026-07-08 07:46
---
Implemented all 4. Verified what is locally verifiable before pushing: (a) --total-shards=4/--shard-index sharding sums to exactly 1314 across all 4 shards (full suite, no gaps/overlap); (b) both halves of the native-tests split run correctly in sequence locally -- the warm-up (PairingWindowTimeoutTest alone) succeeds, then the full gradlew :app:testDebugUnitTest succeeds as a separate invocation; (c) analyze clean. Could NOT test the lcov --ignore-errors empty removal locally (no lcov on this Windows dev box, same limitation as TASK-297) -- watching the live CI dispatch closely for the coverage-gate job specifically.
---

author: Claude
created: 2026-07-08 07:52
---
Done, confirmed green via live CI dispatch 28926389770 (all 8 jobs succeeded). Confirmed each fix actually worked as designed from the live logs, not just "build passed": coverage-gate merged all 4 shards with empty dropped from --ignore-errors and still computed 68.0% (7919/11653) correctly -- no shard silently missing; native-tests job log shows the exact intended step sequence (Write local.properties -> Warm the Robolectric SDK-jar cache (retried) -> Native unit tests (unretried)) all succeeding independently. Files: .github/workflows/ci.yml.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
