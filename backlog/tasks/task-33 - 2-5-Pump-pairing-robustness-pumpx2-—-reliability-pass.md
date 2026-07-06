---
id: TASK-33
title: 2-5 Pump pairing robustness (pumpx2) — reliability pass
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §2
  - phase-4
  - pump
  - "\U0001F50C hardware"
dependencies: []
priority: high
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Native read path, pairing dialog, reconnect done; JPAKE pairing VERIFIED end-to-end on a real t:slim X2 (Jul 2026) after two fixes: (a) scheme defaulted to 16-char, never JPAKE 6-digit — now selects SHORT_6CHAR when no derived secret cached; (b) submitPairingCode only called pair() with a CentralChallenge, but JPAKE supplies none — now always calls pair(). Remaining: real-hardware reliability pass — pairing retries, reconnect, error surfacing, t:connect mutual-exclusion, long-run stability; tighten the reconnect/pairing-window loop (pump drops the link before service discovery when not actively on its Pair screen); consider gating the derived-secret reuse path. P1-4/P1-5 first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pairing retries + reconnect robust on hardware
- [ ] #2 Error surfacing to UI
- [ ] #3 t:connect mutual-exclusion handled
- [ ] #4 Long-run stability verified
- [ ] #5 Reconnect/pairing-window loop tightened
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §2 item 2-5
Effort: M
Depends on: P1-4, P1-5
Flags: 🔌 hardware
Roadmap status: partial (JPAKE pairing verified)
<!-- SECTION:NOTES:END -->
