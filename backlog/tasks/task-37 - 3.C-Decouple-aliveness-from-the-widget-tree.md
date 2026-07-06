---
id: TASK-37
title: 3.C Decouple aliveness from the widget tree
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - phase-3
  - architecture
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Alert evaluation runs off a ref.listen in app.dart; engine dies → alerts die. Staged: (1) pure decision core evaluate(AlertInputs)→List<AlertDecision>, unit-test the matrix; (2) native urgent-low backstop in PumpService (dumb threshold, hysteresis, Flutter-alive heartbeat suppression); (3) headless Dart evaluation via WorkManager/isolate — only after §3.H single-connection fix; (4) until then, document the limitation in the guide.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pure decision core with matrix tests
- [ ] #2 Native urgent-low backstop
- [ ] #3 Headless Dart evaluation (post-§3.H)
- [ ] #4 Guide documents the limitation until done
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.C (P1-7)
Effort: L
Depends on: §3.H for step 3
Flags: 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
