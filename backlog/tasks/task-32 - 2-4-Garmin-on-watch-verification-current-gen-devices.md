---
id: TASK-32
title: Garmin on-watch verification + current-gen devices
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:10'
labels:
  - roadmap
  - garmin
  - "\U0001F50C hardware"
milestone: m-4
dependencies: []
priority: medium
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's Garmin app has only been checked in Garmin's on-computer simulator, not installed on a real watch, and the app's device list ("manifests") is missing current-generation watches.

**Reason for change.** Phone-to-watch data push and the background service only truly prove out on hardware, and missing devices mean the app won't install on newer watches (fenix 8, Forerunner 165/970, venu/vivoactive 6).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Installed + verified on a paired watch
- [ ] #2 Phone→watch push + background service confirmed
- [ ] #3 Current-gen devices added to manifests
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Install on a paired watch.
- Confirm phone→watch push + background service.
- Add fenix 8, FR 165/970, venu/vivoactive 6 to the 3 manifests.
- Raise `minApiLevel` or prune products lacking `registerForPhoneAppMessageEvent`.
- On-watch test: install, confirm live BG push + background survival; build succeeds for each added device.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 2 item 2-4
- Effort: S–M
- Flags: 🔌 hardware
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
