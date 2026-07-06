---
id: TASK-33
title: Pump pairing robustness (pumpx2) — reliability pass
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:10'
labels:
  - roadmap
  - pump
  - "\U0001F50C hardware"
milestone: m-4
dependencies:
  - TASK-12
priority: high
ordinal: 33000
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
