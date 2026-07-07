---
id: TASK-98
title: Golden/screenshot tests
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 14:36'
labels:
  - roadmap
  - testing
  - detail-needed
milestone: m-7
dependencies: []
priority: low
ordinal: 109700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** "Golden" (screenshot) tests capture reference images of screens and fail if the UI changes unexpectedly. The harness exists but no baselines are wired up.

**Reason for change.** Golden tests catch visual regressions automatically, so an accidental layout break is caught in testing rather than on a device.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Golden tests for the key screens via the existing harness
- [ ] #2 Run in CI or a documented manual command
- [ ] #3 Baseline images committed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add golden/screenshot tests via the existing harness (`test_driver/screenshot_driver.dart` + `integration_test/screenshots_test.dart`).
- Establish baseline images.
- Wire into CI or a documented manual command.
- Testing: golden tests for the key screens; baselines committed; run documented.
- Add/extend an integration test in demo mode under `integration_test/` (pumpDemoApp harness); `flutter analyze` clean, `flutter test` green; update `doc/user-guide.html` in the same change (CLAUDE.md).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 6
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:24
---
detail-needed (2026-07-06, goal triage): Golden/screenshot tests need a decision on which screens + baseline images captured on a chosen device/CI, then wired in.
---

author: Claude
created: 2026-07-07 14:36
---
detail-needed (2026-07-08): blocked on the same environment limitation just found on TASK-195 — flutter test/drive against the emulator fails with a VM-service WebSocketChannelException in this session (confirmed pre-existing via an existing, previously-passing integration test, not specific to any one test file; ruled out sandbox restrictions and a stale adb server). Golden-image generation needs flutter drive -d <device>, so this is fully blocked until a session with a reachable emulator VM-service port. See memory integration-test-emulator-limitation.
---
<!-- COMMENTS:END -->
