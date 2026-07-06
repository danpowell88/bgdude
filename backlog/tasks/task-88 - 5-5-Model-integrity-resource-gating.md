---
id: TASK-88
title: 5-5 Model integrity & resource gating
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §5
  - panel-scanner
  - "\U0001F9E0 llm"
  - security
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
URL + SHA-256 stored and verified (with P1-9's host/HTTPS rules); free-space check before download, RAM check before load (silent-null failure today); reconcile the 0.5 GB vs 1.5 GB claims by measuring on the Pixel.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 SHA-256 + host/HTTPS verification
- [ ] #2 Free-space + RAM checks before download/load
- [ ] #3 Space/RAM figures reconciled by measurement
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 5 (overlaps P1-9)
Effort: M
Depends on: P1-9
Flags: 🧠 llm 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
