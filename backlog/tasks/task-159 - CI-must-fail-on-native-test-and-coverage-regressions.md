---
id: TASK-159
title: CI must fail on native-test and coverage regressions
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 09:13'
updated_date: '2026-07-06 22:15'
labels:
  - code-health
  - infra
  - testing
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 100800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `.github/workflows/ci.yml:69-74` runs the Kotlin tests with `continue-on-error: true`, so `ProtocolProbeTest` (the only automated guard on the read-only-pump guarantee) and `PumpResponseMapperTest` (mU→U conversions) can go red while the build stays green. CI runs only `flutter test test/` with no coverage measurement or threshold, and `integration_test/` is never executed anywhere.

**Reason for change.** A red native suite or a coverage collapse currently leaves `main` green; the safety-critical native guards must be blocking and coverage must be measured.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Native test step is blocking: the `local.properties` setup is fixed robustly instead of hiding failures with `continue-on-error: true`
- [ ] #2 CI runs `flutter test --coverage` and gates on an lcov minimum threshold
- [ ] #3 Integration tests either get a scheduled emulator job or are explicitly documented as manual-only (decide and document)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Make the Kotlin test step blocking; write `local.properties` (sdk.dir, flutter.sdk) deterministically before Gradle runs.
- Switch the Flutter test step to `flutter test --coverage` and add an lcov minimum-threshold gate.
- Decide the `integration_test/` story: scheduled emulator job vs documented manual-only; implement or document the decision.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 1)
- Effort: S
- Where: `.github/workflows/ci.yml`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 22:07
---
Started: make the Kotlin test step blocking with deterministic local.properties, add flutter test --coverage + lcov threshold gate, and document the integration_test story (manual-only, given no emulator in CI).
---

author: Claude
created: 2026-07-06 22:15
---
Device-testing sweep 2026-07-07: the integration-test policy decision this ticket left open is resolved by the new CI emulator-job ticket TASK-219 (nightly schedule + workflow_dispatch, not per-push blocking) — reference it in AC#3 when implementing.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
