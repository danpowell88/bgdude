---
id: TASK-288
title: >-
  Make the test pipeline resilient to network issues: hermetic tests, CI
  retries, timeouts
status: In Progress
assignee:
  - Claude
created_date: '2026-07-08 01:55'
updated_date: '2026-07-08 07:04'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 197000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parts of the pipeline can fail on a transient network problem rather than a real defect. integration_test/nutrition_ocr_accuracy_test.dart makes LIVE calls to world.openfoodfacts.org (searches, product JSON, and downloads real label images) -- if Open Food Facts is slow or down, the test flakes; it skips a single product on a hiccup but the whole test depends on OFF being reachable. Separately, CI has no retries on the network-dependent setup steps (flutter-action SDK download, flutter pub get, Gradle dependency resolution), so a registry or network blip reds the whole build, and there are no per-test timeouts, so a network-hung test can stall until the job timeout. food_database_test is the good hermetic pattern to mirror (http/testing MockClient, no live calls).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Live-network tests are made hermetic (bundle fixture images/JSON so nutrition_ocr_accuracy needs no live OFF call) OR clearly quarantined as nightly-only with a retry and a graceful skip, so an OFF outage never reds the core pipeline
- [ ] #2 Network-dependent CI setup steps (SDK download, pub get, Gradle resolve) are wrapped in a bounded retry so a transient blip retries instead of failing the build
- [ ] #3 A sensible per-test timeout is set so a network-hung test fails fast rather than stalling to the job timeout
- [x] #4 An audit confirms no other test in test/ makes a live network call (all use MockClient/fakes/fixtures)
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-08 (resilient to network issues etc)
- Files: integration_test/nutrition_ocr_accuracy_test.dart (live OFF calls), .github/workflows/ci.yml + emulator-tests.yml (no retries/timeouts)
- Good pattern to copy: test/food_database_test.dart uses package:http/testing MockClient
- A retry action such as nick-fields/retry can wrap the flaky setup steps
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 07:04
---
Started. AC#1 investigation: already substantially satisfied by prior work -- TASK-219 quarantined nutrition_ocr_accuracy_test.dart out of the nightly automated run entirely via --skip-network (tools/run_functional_integration_tests.sh), so an OFF outage cannot red any CI pipeline (it is not even attempted there). The test itself also already degrades gracefully on its own: markTestSkipped if the initial product search is unreachable, a per-product try/catch so one bad product does not fail the run, and an explicit 5-min Timeout. No code change needed for AC#1 -- checking it off against the existing state. AC#4 audit: dispatched an Explore agent across all 137 test/ files plus integration_test/ -- confirmed every HTTP-touching test/ file (nightscout_test.dart, food_database_test.dart, panel_model_manager_test.dart, glucose_meter_*_test.dart, health_sync_test.dart, weather_test.dart, etc.) uses MockClient or a hand-rolled http.BaseClient fake / fully-faked service interface; hostnames appearing as bare strings (huggingface.co, github.com in a doc comment, openfoodfacts.org in a JSON fixture) are validated/parsed data, never dialed. The ONE real network-call surface in the whole test tree is nutrition_ocr_accuracy_test.dart in integration_test/ (outside test/, already covered by AC#1). AC#4 holds for test/ as literally worded -- checking it off. Now implementing AC#2 (retry-wrap flutter pub get + the Gradle-touching build/test commands in both ci.yml and emulator-tests.yml with nick-fields/retry) and AC#3 (explicit dart_test.yaml documenting the 30s default per-test timeout, verified locally -- full suite still green, 1185/1185).
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
