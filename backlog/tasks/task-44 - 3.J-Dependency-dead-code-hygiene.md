---
id: TASK-44
title: 3.J Dependency & dead-code hygiene
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - phase-0
  - cleanup
dependencies: []
priority: low
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove unused deps (riverpod_annotation, freezed/freezed_annotation, json_serializable). Delete or wire NightscoutClient.uploadTreatments (declared, never called). Cap DayHistoryController._basalObs (unbounded within a session) with the PumpEventLog.maxEvents ring pattern.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Unused deps removed
- [ ] #2 uploadTreatments wired or deleted
- [ ] #3 _basalObs capped
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.J
Effort: S
Roadmap status: open
<!-- SECTION:NOTES:END -->
