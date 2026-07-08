---
id: TASK-297
title: Shard the CI unit-test job across a matrix
status: Done
assignee:
  - Claude
created_date: '2026-07-08 04:18'
updated_date: '2026-07-08 06:38'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 196500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split off from TASK-287 (AC#1, deliberately deferred as its own careful pass). flutter test --coverage test/ (1161+ tests, one process) is the test job's dominant cost. Shard across a matrix (e.g. by directory or a partition file), merge per-shard lcov.info files before the coverage gate runs, and keep the gate's floor check working on the merged total.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 flutter test runs sharded across a matrix strategy
- [x] #2 Coverage is merged across shards before the gate check runs, and the gate still correctly fails a real coverage regression
- [x] #3 Wall-clock for the test job drops materially vs the unsharded baseline
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: split from TASK-287 2026-07-08
- File: .github/workflows/ci.yml test job
- Related: TASK-159/275 own the coverage gate this must keep intact
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 06:27
---
Started: sharding the unit-test job across 4 matrix shards, split by test/ subdirectory (natural now that TASK-276 grouped test/ by feature). Verified locally that the 4 shard groups exactly partition the suite -- 308+277+206+394 = 1185, matching the unsharded total exactly, all passing. Coverage merge uses lcov --add-tracefile (sums per-line hit counts across shards for files touched by more than one, so the merged percentage is exact) in a new coverage-gate job that runs after all 4 shards, then applies the unchanged floor-check script. Could NOT test the lcov merge step itself locally -- this Windows dev box has no lcov/apt-get -- so this needs a live CI dispatch to confirm before its trusted; watching the next push closely.
---

author: Claude
created: 2026-07-08 06:38
---
Done and confirmed green via live CI dispatch 28922633296. AC#1: 4 matrix shards, split by test/ subdirectory. AC#2: coverage-gate job merges shard lcov.info files with lcov --add-tracefile and applies the unchanged floor check -- confirmed EXACT: the merged CI result (67.9%, 7917/11653 lines) matches my local unsharded flutter test --coverage test/ run bit-for-bit (LH=7917 LF=11653), so the merge neither double-counts nor drops coverage; the gate would still correctly fail a real regression since its the same awk floor check as before, just fed a correctly-merged file. AC#3: each shard now runs in ~2m10s-2m47s vs the unsharded jobs 4m18s -- a ~40% cut to the dominant cost, material per the AC even though the overall pipeline wall-clock is still bounded by apk-build (~4m22s) and the new coverage-gate step adds ~31s sequenced after the last shard. One hotfix needed: the coverage-gate job has no checkout step (does not need the repo, only downloaded artifacts), so coverage/ did not exist for lcov to write to on the first attempt -- fixed with a plain mkdir -p coverage, confirmed on the second dispatch. Files: .github/workflows/ci.yml. Commits: e14c6bd (shard + merge), 3d4db41 (mkdir hotfix).
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
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
