---
id: TASK-147
title: 'EffectiveLowThreshold: one composed low-line policy'
status: To Do
assignee: []
created_date: '2026-07-06 08:42'
updated_date: '2026-07-06 12:57'
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
- [ ] #1 An `EffectiveLowThreshold.compute({base, profile, annotations, exercisePlan, tempC, now})` returns the composed line plus active reasons
- [ ] #2 It is consumed by `AlertService`, `PreBolusCoach`, and the rescue-carb path
- [ ] #3 The `AlcoholWatch` dead constant is either consumed or removed with the additive margin documented
- [ ] #4 Unit tests cover each modifier and their composition
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
