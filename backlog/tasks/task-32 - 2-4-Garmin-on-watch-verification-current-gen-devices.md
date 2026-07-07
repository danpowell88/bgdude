---
id: TASK-32
title: Garmin on-watch verification + current-gen devices
status: To Do
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 13:00'
labels:
  - roadmap
  - garmin
  - "\U0001F50C hardware"
milestone: m-4
dependencies: []
priority: medium
ordinal: 500400
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
- [x] #3 Current-gen devices added to manifests
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 12:55
---
AC#3 done: added fenix8 (843mm/847mm/pro47mm/solar47mm/solar51mm), fr165/fr165m, fr970, and venu441mm/venu445mm (Venu 4) + vivoactive6 to all 3 manifests (manifest.xml, manifest-datafield.xml, manifest-watchface.xml) — same set in each, matching the existing pattern. Verified the exact product IDs against the installed Connect IQ SDK's own device catalog (sdkmanager-config.ini's full list of every device ID the SDK manager has ever seen), not guessed or web-search-summarized. Compiled the widget for fr970 (a locally-simulator-downloaded device) with a throwaway local dev key to confirm the manifest changes don't break the build — BUILD SUCCESSFUL. The compiler warns 'invalid device id' for my new IDs, but it does the SAME for many pre-existing IDs already in the manifest (venu, fenix6, fr255, etc.) — that's just this machine's SDK not having every device's simulator package downloaded, not a real problem with the IDs (confirmed: the IDs I verified via the SDK's device catalog, like fenix8-variants and fr970, aren't in that warning list once their simulator package IS present locally). AC#1 (installed + verified on a paired watch) and AC#2 (phone->watch push + background service confirmed) remain hardware-gated — no physical Garmin watch available in this environment.
---
<!-- COMMENTS:END -->
