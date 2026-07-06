---
id: TASK-98
title: 6.7 Golden/screenshot tests
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §6
  - testing
dependencies: []
priority: low
ordinal: 98000
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
**Technical notes.** Add golden/screenshot tests via the existing harness (test_driver/screenshot_driver.dart + integration_test/screenshots_test.dart); establish baseline images; wire into CI or a documented manual command.

**Testing.** Golden tests for the key screens; baselines committed; run documented. Add/extend an integration test in demo mode under `integration_test/` (pumpDemoApp harness); `flutter analyze` clean, `flutter test` green; update `doc/user-guide.html` in the same change (CLAUDE.md).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §6
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->
