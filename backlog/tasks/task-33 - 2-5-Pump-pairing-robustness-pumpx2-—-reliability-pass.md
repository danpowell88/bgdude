---
id: TASK-33
title: Pump pairing robustness (pumpx2) — reliability pass
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 12:58'
labels:
  - roadmap
  - pump
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies:
  - TASK-12
priority: high
ordinal: 500000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude connects to the Tandem t:slim X2 pump over Bluetooth to read (never write) data. Pairing was proven end-to-end on a real pump in July 2026 after fixing two bugs in the pairing handshake ("JPAKE", the pump's 6-digit-code exchange). It works, but the connection is still fragile.

**Reason for change.** The pump drops the link if it isn't sitting on its pairing screen at just the right moment, and long-run stability plus the "only one app can pair at a time" rule with Tandem's official app are unproven. Two prerequisite crash fixes (P1-4/P1-5) must land first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pairing retries + reconnect robust on hardware
- [ ] #2 Error surfacing to UI
- [ ] #3 t:connect mutual-exclusion handled
- [ ] #4 Long-run stability verified
- [ ] #5 Reconnect/pairing-window loop tightened
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add pairing retries and reconnect after drop.
- Surface errors to the UI.
- Handle t:connect mutual-exclusion.
- Verify long-run stability.
- Tighten the reconnect/pairing-window loop.
- Consider gating the derived-secret reuse path.
- On-device test: repeated pair/unpair, reconnect after sleep/range-loss, multi-hour stability; confirm the read-only guarantee (only `currentStatus` sent) holds throughout.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 2 item 2-5
- Effort: M
- Depends on: TASK-12 (P1-5), P1-4
- Flags: 🔌 hardware
- Roadmap status: partial (JPAKE pairing verified)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 12:58
---
detail-needed (2026-07-07, hardware gate): every remaining AC (#1 pairing retries/reconnect, #2 error surfacing, #3 t:connect mutual-exclusion, #4 long-run stability, #5 reconnect-window tightening) explicitly requires 'on-device (hardware): prepare a build + run on the real device' per the ticket's own plan — none of it is a desk-verifiable software gap. No physical Tandem t:slim X2 pump is available in this environment. Left In Progress (roadmap status already 'partial — JPAKE pairing verified' from a prior real-hardware session) rather than Done, since the actual reliability work hasn't happened yet, or detail-needed-and-abandoned, since it's real, scoped, ready-to-run work waiting on hardware access.
---
<!-- COMMENTS:END -->
