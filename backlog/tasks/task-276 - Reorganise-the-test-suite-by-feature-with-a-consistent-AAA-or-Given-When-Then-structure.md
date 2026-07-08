---
id: TASK-276
title: >-
  Reorganise the test suite by feature with a consistent AAA or Given-When-Then
  structure
status: In Progress
assignee:
  - Claude
created_date: '2026-07-07 21:47'
updated_date: '2026-07-08 05:57'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 195000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The unit test suite is 131 flat *_test.dart files in the top of test/ (only 2 are nested), so tests are not grouped by feature and related behaviour is scattered. Test names and comments also carry 197 TASK-nnn references across 94 files, which couple the tests to backlog IDs that mean nothing to a future reader; provenance belongs in git history and the backlog, not in test names. Structure is inconsistent and some tests read as terse assertions without saying what real behaviour they pin (this is the same surface where the loop keeps finding hollow/tautological tests, e.g. TASK-251, TASK-257, TASK-270 — a clear WHAT/WHY/expected-outcome structure makes hollowness obvious). Reorganise the suite so a reader can find and understand tests by feature.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tests are grouped by feature (subdirectories under test/ mirroring the lib/ feature areas, or feature-named group() blocks) instead of a flat 131-file directory
- [ ] #2 TASK-nnn references are removed from test names and descriptions across the suite (provenance stays in git/backlog); the ~197 mentions are gone
- [ ] #3 Each test follows a consistent structure -- AAA (Arrange-Act-Assert) or Given-When-Then -- applied uniformly
- [ ] #4 Every test (or its enclosing group) has enough context to explain WHAT is under test, WHY it matters, and WHAT the expected behaviour is -- a descriptive name plus a short comment where the why is non-obvious
- [ ] #5 The reorg is behaviour-preserving: no test is dropped or weakened and line coverage does not drop (pure move/rename/reword)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Agree the feature taxonomy (e.g. analytics, ml, pump, data, insights, ui, integrations, reports) and the target folder layout under test/.
2. Move files into feature folders; update imports; keep the run green after each folder to avoid a single massive unreviewable change.
3. Strip TASK-nnn from test/group names and descriptions in the same pass per file.
4. Normalise each moved test to AAA or Given-When-Then and add a one-line why where non-obvious.
5. Confirm flutter test --coverage test/ stays green and coverage does not drop; update any test-path references in CI or docs if needed.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-08
- Current state: 131 top-level test files + 2 nested; 197 TASK-nnn mentions across 94 files
- Large mechanical change -- tackle per feature incrementally so PRs stay reviewable and CI stays green throughout
- Related: TASK-251 / TASK-257 / TASK-270 (hollow-test findings) -- a clear expected-behaviour structure helps prevent the recurrence
- Keep the always-update-user-guide and coverage-ratchet DoD in mind; this is test-only so no user-guide impact
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 05:57
---
Started: this is a large 137-file mechanical reorg, tackling it incrementally per the plan (one AC/slice per commit, verified green each time) rather than one huge change. Slice 1 (this session): AC#1 only -- physical move into feature subfolders mirroring lib/ (alerts, analytics, data, food, insights, ml, onboarding, profile, pump, reports, state, ui, weather, widget, integrations, logging, meals), fixing the ~20 relative support/ imports that break on move, verified with a full analyze+test pass. AC#2 (strip ~246 TASK-nnn mentions across 100 files) and AC#3/4 (AAA/Given-When-Then normalization + WHAT/WHY context on every test) are deliberately deferred to follow-up slices -- AC#3/4 in particular means touching the body of every test in the suite, which is much higher risk to behaviour-preservation (AC#5) than a pure file move, so it needs its own careful pass rather than being rushed alongside the physical reorg.
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
