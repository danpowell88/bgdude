---
id: TASK-147
title: 'EffectiveLowThreshold: one composed low-line policy'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:42'
updated_date: '2026-07-06 22:07'
labels:
  - code-health
  - alerts
  - dosing-math
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 100700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The effective low line is assembled inline in `AlertService.onSnapshot` (`lib/state/providers.dart:1417-1437`: hypo-awareness bump, alcohol `+10`, exercise `lowBump`, weather bump) and nowhere else — `PreBolusCoach` uses a fixed `lowGuardMgdl = 81` (`lib/meals/prebolus_coach.dart:51`) ignoring all modifiers, so the app can advise pre-bolusing into a situation it would alert on. Also `AlcoholWatch.raisedLowMgdl = 80` (`lib/insights/alcohol_watch.dart:13`) is dead — the code uses the magic `+10` instead, contradicting its doc.

**Reason for change.** Two surfaces disagree about where "low" starts; one composed policy makes coaching and alerting consistent and kills a dead, contradicting constant.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 An `EffectiveLowThreshold.compute({base, profile, annotations, exercisePlan, tempC, now})` returns the composed line plus active reasons
- [x] #2 It is consumed by `AlertService`, `PreBolusCoach`, and the rescue-carb path
- [x] #3 The `AlcoholWatch` dead constant is either consumed or removed with the additive margin documented
- [x] #4 Unit tests cover each modifier and their composition
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Implement `EffectiveLowThreshold.compute({base, profile, annotations, exercisePlan, tempC, now})` returning the line plus active reasons.
- Consume it from `AlertService`, `PreBolusCoach`, and the rescue-carb path.
- Resolve `AlcoholWatch.raisedLowMgdl`: consume it or remove it, documenting the additive margin.
- Add unit tests per modifier and for composition.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:1417-1437`, `lib/meals/prebolus_coach.dart:51`)
- Effort: M
- Where: new policy file, `lib/state/providers.dart`, `lib/meals/prebolus_coach.dart`, `lib/insights/alcohol_watch.dart`
- Related: TASK-103; distinct from TASK-58/TASK-60
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 21:58
---
Started: new EffectiveLowThreshold.compute policy (line + active reasons); resolveEffectiveThresholds (TASK-116) delegates to it; wire PreBolusCoach and the rescue-carb path to the composed line; resolve AlcoholWatch.raisedLowMgdl.
---

author: Claude
created: 2026-07-06 22:07
---
Done (commit 62661e6). Note: the pre-bolus guard uses max(coach floor 81, effective line) rather than the effective line alone — the coach keeps its conservative floor when no modifier is active. UI reads the line via effectiveLowThresholdProvider (annotations degrade gracefully to [] while the async fetch is in flight).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New lib/insights/effective_low_threshold.dart: EffectiveLowThreshold.compute({base, profile, annotations, exercisePlan, tempC, now}) returns the composed line + active reasons (modifiers compose via max over base, not stacking). Consumed by: (1) AlertService via resolveEffectiveThresholds (which now delegates and carries lowReasons), (2) rescue-carb path via new lowLineMgdl param + effectiveLowThresholdProvider, (3) PreBolusCoach.advise via effectiveLowMgdl with guard = max(81, effective) so it never advises waiting into an alert situation. AlcoholWatch.raisedLowMgdl (dead, contradicting) replaced by consumed additive lowBumpMgdl=10 with the margin documented; research pin test updated. 11 unit tests cover each modifier + composition + custom-base lead. Guide updated (rescue card, pre-bolus coach). Verified: analyze clean, 627 tests green, debug APK builds. Commit 62661e6.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
