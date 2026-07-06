---
id: TASK-88
title: Model integrity & resource gating
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:58'
labels:
  - roadmap
  - panel-scanner
  - "\U0001F9E0 llm"
  - security
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies: []
priority: medium
ordinal: 500600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The AI model file is large and downloaded on demand. Today there's no integrity check on the download, and no check that the phone has enough free space or memory before using it (it just silently fails).

**Reason for change.** Verifying the download's fingerprint (SHA-256) and checking free space/RAM up front — with a clear message on failure — makes model management safe and predictable. Overlaps the download-security fix (P1-9).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 SHA-256 + host/HTTPS verification
- [ ] #2 Free-space + RAM checks before download/load
- [ ] #3 Space/RAM figures reconciled by measurement
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Store + verify the model URL and SHA-256 (with P1-9 host/HTTPS rules).
- Free-space check before download, RAM check before load (silent-null failure today).
- Reconcile the 0.5 GB vs 1.5 GB size claims by measuring on the Pixel.
- Unit tests: wrong SHA-256 rejected; insufficient space/RAM blocks with a clear message.
- Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 5 item 5 (overlaps P1-9)
- Effort: M
- Depends on: TASK-16 (P1-9)
- Flags: 🧠 llm 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:28
---
detail-needed (2026-07-06, goal triage): Model integrity/resource gating needs the concrete model URL + published SHA-256 and on-device RAM/space measurement to reconcile the 0.5 vs 1.5 GB claim.
---
<!-- COMMENTS:END -->
