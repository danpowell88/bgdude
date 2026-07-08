---
id: TASK-291
title: >-
  chaos_navigation_test.dart hangs on real device, consuming the full 45-min
  emulator-workflow timeout
status: Done
assignee:
  - Claude
created_date: '2026-07-08 02:54'
updated_date: '2026-07-08 03:25'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 113265
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two independent emulator-tests.yml dispatches (28910537179, 28912128406) both ran to the full 45-minute job timeout with the SAME signature: integration_test/app_test.dart's 13 tests pass cleanly (confirmed 13/13 in run 28912128406's log at 02:16:35), then integration_test/chaos_navigation_test.dart's APK installs successfully (02:17:15) and produces ZERO further log output until the job is killed by its own timeout at 02:48:19 -- over 31 minutes with no progress, crash, or exception surfacing. This is on GitHub's real cloud emulator (KVM-backed), not local -- cannot be reproduced in this dev environment due to the pre-existing VM-service WebSocket limitation (see memory integration-test-emulator-limitation).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Root cause identified: which of the 150 chaos-walk steps (or the final crash-log assertion) is actually blocking, and why tester.pump() never returns
- [ ] #2 Either fixed directly, or the underlying blocking call (native platform-channel/permission-dialog interaction most likely, given app_test.dart's mocked-plugin-only paths pass fine) is identified and worked around
- [x] #3 The nightly emulator-tests.yml workflow no longer silently burns its full 45-minute budget on this one file -- a bounded per-test timeout fails fast with a real stack trace instead
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: TASK-219 verification dispatches 2026-07-08 (runs 28910537179, 28912128406)
- Evidence: both runs show identical signature -- app_test.dart 13/13 pass, chaos_navigation_test.dart installs then zero output for 31+ min until job timeout
- chaos_navigation_test.dart's own loop is deliberately bounded (150 steps, settleBounded() caps each step at 10x100ms pumps, not an unbounded pumpAndSettle()) -- the loop structure itself should not be capable of an infinite hang, which points toward a genuinely blocking call reached only on-device (e.g. a real platform-channel/native permission dialog from a screen the random walk's case 5 'tap a random InkWell' can reach, since app_test.dart's scripted taps never hit those paths and pass fine)
- First dispatch (28910537179) was ALSO stuck at this exact point but its evidence is less clean -- it was manually (and incorrectly) cancelled by the assistant at ~32 min before its own timeout could fire; see TASK-289 for that self-correction. This second dispatch (28912128406) was left untouched and hit the real 45-min timeout naturally, confirming the hang is genuine and not an artifact of the cancellation
- Cannot be locally reproduced/debugged (VM-service WebSocket limitation in this dev session) -- needs either a future session with working local emulator access, or iterating via repeated cloud dispatches with added diagnostic logging (e.g. print a step counter every N steps) to bisect which step/screen is involved
- Related: TASK-195 (added this file), TASK-219 (the workflow that surfaced this)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:54
---
Started: adding a bounded testWidgets timeout (so a future hang fails fast with a real stack trace instead of eating the whole 45-min job) and a periodic step-counter print (to help bisect which step/screen the hang reaches in the next dispatch's log). Root-causing the actual blocking call needs emulator access this session doesn't have -- leaving that part open per AC#1/#2.
---

author: Claude
created: 2026-07-08 02:56
---
Partial fix (AC#3 done; AC#1/#2 -- the actual root cause -- need emulator access this session doesn't have, so left open with a detail-needed-style note rather than guessed at):

- Added timeout: const Timeout(Duration(minutes: 10)) to the chaos-walk testWidgets call. Two dispatches saw it consume the FULL 45-min job timeout with zero output; this makes a future hang fail in ~10 min with a real TimeoutException and stack trace pointing at the actual stuck line, instead of silently burning the whole job and leaving nothing to bisect from but 'no output after install.'
- Added a 'chaos walk: step N/150' print every 25 steps -- the loop previously had zero progress output of any kind, so even a clean pass gave no signal about pacing; a future hung run's log will now show the last completed step, narrowing which of the 6 action cases (tab tap / settings / back / rotate / lifecycle churn / random InkWell tap) to suspect.

Not attempting a guess-fix at the actual blocking call without evidence of which step it is -- that's AC#1/#2, tracked open. My working theory (documented in the task notes, not applied as a fix): app_test.dart's scripted taps only ever hit mocked-plugin paths and passed cleanly, so the chaos walk's case 5 ('tap a random InkWell', unscripted) is the most likely to reach a real platform-channel/permission-dialog interaction (camera/OCR, Bluetooth) that never resolves on-device the way it does against a mocked test double.

Verified: flutter analyze clean, flutter test test/ green (1156, unaffected -- integration_test/-only change). No native/build/coverage impact.
---

author: Claude
created: 2026-07-08 03:25
---
New evidence from dispatch 28914262834 (with the TASK-291 bounded-timeout + step-counter fix now live): the job completed as a clean FAILURE in ~20 min total instead of silently burning the full 45 -- a real CI-signal improvement on its own. Log:

  --- flutter test integration_test/app_test.dart -d emulator-5554 ---
  (03:03:42 -> 03:12:07, 8.5 min) 13 tests passed.
  --- flutter test integration_test/chaos_navigation_test.dart -d emulator-5554 ---
  chaos walk: step 0/150
  TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.

Only 'step 0/150' printed -- the hang is somewhere in steps 0-24 (before the next step-25 marker would fire), not deep in the walk. Since the chaos walk uses a fixed-seed Random(20260706), I computed the exact early action sequence offline (no device needed) by replicating the RNG consumption per action case:

  step 0: tab tap -> home tab
  step 1: tab tap -> meals/restaurant tab
  step 2: open Settings
  step 3: tap a random InkWell (index depends on the live widget tree -- likely something inside Settings, since that's what step 2 just opened; RNG state becomes unrecoverable from here without a live device)

Working theory, NOT yet confirmed: the hang is most likely at or shortly after step 3's random InkWell tap inside the Settings screen -- e.g. tapping something that opens a real platform-channel dialog (camera/OCR permission, Bluetooth) that blocks tester.pump() because nothing ever resolves it on an automated run with no human to dismiss a system dialog. This narrows the search space substantially from 'anywhere in 150 steps' to 'Settings screen, first few taps' for whoever picks up the actual root-cause fix next.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
