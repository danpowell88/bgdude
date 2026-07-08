---
id: TASK-287
title: >-
  Speed up the CI test pipeline: shard the unit tests, parallelise jobs, cache
  codegen
status: In Progress
assignee:
  - Claude
created_date: '2026-07-08 01:54'
updated_date: '2026-07-08 03:57'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 196000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The CI pipeline runs as a single sequential job (ci.yml): pub get, then build_runner, then analyze, then flutter test --coverage test/ (about 962 test() calls in one unsharded run), then flutter build apk --debug. The two slowest blocks (codegen and the APK build) run serially on the critical path with the test run, and nothing is sharded, so wall-clock is the sum of everything. Three levers: (1) shard flutter test across a matrix so the largest serial block runs in parallel; (2) run analyze, unit tests, and the APK build as parallel jobs rather than one sequential job (the APK build does not depend on the test result); (3) cache the build_runner output keyed on a hash of pubspec.lock plus the drift schema and annotated sources, skipping regeneration when inputs are unchanged. build_runner is called out in CLAUDE.md as both slow and the step most likely to break CI, so caching it (with correct invalidation) is high value -- but codegen MUST still run when inputs change because the generated *.g.dart files are not committed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 flutter test is sharded across a matrix (coverage still merged for the gate) and the suite wall-clock drops materially
- [x] #2 analyze / unit tests / APK build run as parallel jobs rather than one sequential job
- [ ] #3 build_runner output is cached and skipped when its inputs are unchanged, and correctly regenerated when pubspec.lock or an annotated source changes (verified: a source change still triggers codegen)
- [ ] #4 The coverage gate still runs on the merged coverage and the total pipeline is faster end to end
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-08 (make the test pipeline faster)
- File: .github/workflows/ci.yml (single job, timeout-minutes 30)
- Related: TASK-218 (Gradle cache, done) covered only Gradle deps; TASK-159/275 own the coverage gate that sharding must keep intact
- Codegen-cache invalidation is the risky part -- see the CLAUDE.md verify pipeline note that *.g.dart are not committed
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:50
---
Started: given the 3 levers carry very different risk (parallel jobs is low-risk/self-contained; build_runner caching is explicitly the risky one per the ticket's own note, since a wrong cache invalidation would let stale generated code silently pass tests), scoping this pass to AC#2 (parallel jobs) first, verified via a real push since ci.yml changes can't be tested without dispatching. Will assess AC#1 (sharding) and AC#3 (codegen caching) as separate, more careful follow-up given the correctness risk of getting cache invalidation wrong on the main branch pipeline.
---

author: Claude
created: 2026-07-08 03:57
---
AC#2 done: split ci.yml's single sequential job into 4 independent parallel jobs -- analyze, test (+coverage gate), apk-build, native-tests. Each re-resolves deps independently (no shared artifact/cache scheme -- scoped that out as the riskier AC#3 lever, see below).

Verified native-tests genuinely doesn't need build_runner before trusting this in CI: locally deleted .dart_tool/.flutter-plugins*/build/android-local.properties, ran ONLY flutter pub get (no build_runner, no flutter build apk), then gradlew :app:testDebugUnitTest directly -- built and passed clean. Confirmed this project uses plain MethodChannel (no Pigeon codegen), so Kotlin compilation never consumes Dart-generated (*.g.dart) output; pub get alone is needed only for .flutter-plugins-dependencies (Flutter Gradle plugin registration).

AC#1 (test sharding) and AC#3 (build_runner caching) deliberately NOT attempted in this pass -- AC#3 in particular is explicitly the risky lever (the ticket's own note: wrong cache invalidation could let stale generated code silently pass), and getting it wrong on the MAIN branch pipeline (which CLAUDE.md says must never be left red) isn't something to rush. Leaving both open as a more careful, separately-verified follow-up rather than bundling elevated-risk changes with this safer one.

Verified locally: flutter analyze clean, flutter test --coverage green (1161, 67.5%+), flutter build apk --debug succeeds, gradlew :app:testDebugUnitTest green standalone. YAML syntax validated (python yaml.safe_load). The REAL test is the live CI run once pushed -- watching that now.
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
