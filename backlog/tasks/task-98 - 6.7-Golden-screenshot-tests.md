---
id: TASK-98
title: 6.7 Golden/screenshot tests
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
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
Add golden/screenshot tests to catch UI regressions; the harness already exists (test_driver/screenshot_driver.dart + integration_test/screenshots_test.dart). Establish baseline images and wire into the run.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §6
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Golden tests for the key screens via the existing harness
- [ ] #2 Run in CI or a documented manual command
- [ ] #3 Baseline images committed
<!-- AC:END -->
