---
id: TASK-298
title: >-
  Cache build_runner output in CI, correctly invalidated on source/pubspec.lock
  changes
status: In Progress
assignee:
  - Claude
created_date: '2026-07-08 04:18'
updated_date: '2026-07-08 06:44'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 196600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split off from TASK-287 (AC#3, deliberately deferred -- explicitly the riskiest of the three original levers). Every one of the 4 parallel CI jobs currently reruns dart run build_runner build independently (duplicated cost). Cache the generated output keyed on a hash of pubspec.lock plus all annotated Dart sources, skipping regeneration when unchanged -- but codegen MUST still run correctly when those inputs change, since generated *.g.dart files are not committed. Getting the invalidation wrong would let stale generated code silently pass a run undetected, which is a correctness risk, not just a speed one -- verify explicitly (a real source change still triggers regeneration) before landing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 build_runner output is cached and skipped when pubspec.lock and all annotated sources are unchanged
- [x] #2 A change to an annotated source file (or pubspec.lock) is verified to still trigger full regeneration, not a stale cache hit
- [ ] #3 All 4 parallel jobs benefit from the shared cache rather than each running build_runner independently
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: split from TASK-287 2026-07-08
- File: .github/workflows/ci.yml (all 4 jobs currently duplicate build_runner)
- CLAUDE.md: build_runner is called out as both slow and the step most likely to break CI -- this is the riskiest lever of the original 3, take it carefully
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 06:40
---
Started. Investigated first: git ls-files shows exactly ONE generated file is actually committed (lib/data/database.g.dart, drift schema/query code) -- despite CLAUDE.mds general "generated files are not committed" framing, this one is deliberately committed (see .gitignore comment + SETUP.md). Everything else build_runner reports as "output" (274-680 entries in recent runs) is drift_devs own internal per-file analysis cache (.drift_elements.json/.drift_module.json under .dart_tool/build/generated/), not final Dart code. So the real cost is build_runner re-analyzing ~1400 inputs from a cold cache every job, not regenerating a lot of final output. Approach: cache .dart_tool/build (build_runners own incremental-build/asset-digest cache) keyed on hashFiles(pubspec.lock, lib/**/*.dart, test/**/*.dart, integration_test/**/*.dart), in the 3 jobs that run build_runner (analyze, test matrix x4, apk-build -- native-tests does not). Critically: build_runner build --delete-conflicting-outputs is ALWAYS still invoked for real in every job -- never skipped on a cache hit. Only its internal incremental cache is primed, so buildrunners own well-tested digest-based invalidation (not an external cache-key guess) decides what to redo. This satisfies AC#2 by construction: even a stale/partial cache can only affect speed, never correctness, since the real tool runs every time and detects real changes itself.
---

author: Claude
created: 2026-07-08 06:44
---
AC#2 verified locally before touching CI: with a warm .dart_tool/build (already primed from earlier this session), I added a real column to the AppKv drift table, reran dart run build_runner build --delete-conflicting-outputs, and confirmed lib/data/database.g.dart correctly picked up the new column (10 matches for the new field name in the generated file). Reverted the source change, reran build_runner again, confirmed database.g.dart regenerated back to exactly the committed state (git diff --stat clean, zero residual matches for the test column). This directly proves the safety property the cache relies on: build_runner is never skipped, only primed, and its own incremental engine correctly detects and reflects real changes in both directions -- a warm cache cannot produce stale output.
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
