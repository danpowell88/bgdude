---
id: TASK-306
title: >-
  Drift-triggered retrain has no cooldown -- sustained unfixable drift retrains
  the forecaster every startup
status: Review
assignee:
  - Claude
created_date: '2026-07-09 18:23'
updated_date: '2026-07-10 09:48'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-09 18:23'
updated_date: '2026-07-10 14:03'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-138 drift detection requests an out-of-band forecaster retrain by resetting the trainForecaster throttle stamp to DateTime(2000) whenever drift is sustained (>= 3 consecutive drifting reconciliation runs) -- see _checkForecastDrift, providers.dart:2275-2278. The A/B promotion gate is intact (a retrain can never adopt a worse model -- forecaster_service.dart), so this is SAFE, not a correctness bug. But there is no cooldown/backoff on the out-of-band retrain and the drift streak is only reset on a non-drifting run (providers.dart:2267), never after a retrain attempt. So when drift is sustained-but-unfixable-by-retraining -- a genuine new sensor / seasonal shift where retraining on the still-drifted data keeps failing the gate -- driftingNow stays true, streak stays >= 3 every run, the train stamp is reset to epoch every reconciliation, and a full (expensive) GBM retrain fires on EVERY app startup indefinitely until the drift naturally resolves or enough post-change data accumulates to finally beat the incumbent. That is the exact wasted heat the trainForecaster once-a-day throttle exists to prevent (comment at providers.dart:2195), now defeated for the drift path. On a personal app opened several times a day this is several no-op retrains/day burning battery/CPU.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A drift-triggered out-of-band retrain is rate-limited (e.g. at most once per N hours, or the drift streak resets after a retrain attempt so another full 3-run streak is required) so sustained unfixable drift cannot retrain on every startup
- [x] #2 A drift retrain that fails to promote does not immediately re-request another retrain next startup
- [x] #3 The normal ~20h scheduled retrain is unaffected; a genuine one-off drift still triggers a timely out-of-band retrain
- [x] #4 Test asserts sustained drift does not trigger back-to-back retrains within the cooldown
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-10 (inline; agent review of TASK-138 was cut short by the weekly usage limit) verifying c0cf960
- File: lib/state/providers.dart:2257-2279 _checkForecastDrift (stamp reset to DateTime(2000), streak only reset on non-drifting run); _forecasterTrainingDue :2213; trainForecaster StartupJob :2198
- SAFE (A/B gate prevents adopting a worse model); this is an efficiency/battery issue, not a forecast-correctness one
- TASK-140 (training-data census) was NOT deeply reviewed this pass (weekly limit); low-risk read-only diagnostics -- flag for a later look
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 09:37
author: Claude Fable 5
created: 2026-07-10 10:42
---
branch: task-306
---

author: Claude
created: 2026-07-10 09:37
---
Started: reset the drift streak after ANY out-of-band retrain attempt (not just on a non-drifting reconciliation run) so sustained-but-unfixable drift doesn't retrain every startup, and add a cooldown on the out-of-band retrain trigger itself.
---

author: Claude
created: 2026-07-10 09:48
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- lib/state/providers.dart (_checkForecastDrift: added _driftRetrainRequestedKey latch, gates the out-of-band retrain trigger to at most once per sustained-drift episode, clears when the episode genuinely resolves i.e. a non-drifting reconciliation run); tests: test/state/jobs_test.dart new cases 'sustained-but-unfixable drift requests the out-of-band retrain only ONCE...' and 'a latch left over from an already-resolved episode does not block a genuinely fresh one'; commit pending on branch task-306. Design: chose the AC#1-sanctioned 'streak resets after a retrain attempt' family of fix, implemented as an explicit persisted boolean latch (rather than resetting the numeric streak itself) so the UI's forecastDriftProvider.sustained flag stays accurate/visible for as long as drift genuinely persists, instead of flickering off between the trigger and a fresh 3-run recount -- the streak-reset alternative from the AC would have caused that flicker. Both branches (latch-set-on-trigger, latch-clear-on-resolution) individually rigor-checked (temp-bug + revert, each confirmed the corresponding new test fails with the predicted symptom before reverting). Full pipeline green: analyze clean, 1368 tests passing, coverage 68.78% (floor 65%), apk build succeeded. No native Kotlin changed, no user-visible/UI change (banner behavior already existed from TASK-138, this only changes retrain-request frequency), no screen/flow changed so no integration test.
author: Claude Fable 5
created: 2026-07-10 10:42
---
Moved To Do->In Progress to reflect that work has started: origin/task-306 exists and is 1 commit ahead of main. Recording the branch so the review-and-merge loop can find it and parallel sessions do not duplicate this work. Implementer agent TBD (branch pre-existed this status update).
---

author: Claude
created: 2026-07-10 10:44
---
branch: task-306 (correcting -- was set to In Progress by 3db552f, but the code is actually complete: commit 97b47bd on that branch)
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
