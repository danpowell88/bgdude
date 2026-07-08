---
id: TASK-299
title: >-
  Regenerate the committed Gradle wrapper -- old vintage of unverifiable
  provenance, inconsistent with the pinned 8.11.1
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 04:27'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 119000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The TASK-287 CI hotfixes committed android/gradle/wrapper/gradle-wrapper.jar (a 53636-byte binary), android/gradlew and android/gradlew.bat (removing them from android/.gitignore) so CI could build. But the committed wrapper is an OLD Gradle vintage inconsistent with the distribution it points at, and its provenance cannot be verified from the repo: android/gradlew contains the pre-Gradle-5 function splitJvmOpts() plus eval splitJvmOpts (line 154/157) and gradlew.bat contains the ancient 4NT_args / @eval[2+2] handling (line 52/65) -- both were removed from the modern rewritten wrapper -- while gradle-wrapper.properties pins gradle-8.11.1-all.zip. The official 8.x gradle-wrapper.jar is about 43 KB; this one is 53636 bytes, i.e. not what gradle wrapper --gradle-version 8.11.1 emits. It is functional today (an old wrapper still bootstraps whatever distributionUrl names, and later commits built fine), so this is not a CI breaker -- but committing an unverifiable binary jar of mismatched vintage to a medical companion app is a supply-chain and consistency smell. Regenerate from the official tool so the jar, both scripts, and the distributionUrl are all the same trustworthy 8.11.1 version.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 gradle-wrapper.jar and gradlew/gradlew.bat are regenerated via gradle wrapper --gradle-version 8.11.1 (or the project's chosen version) from an official Gradle install so all three match the pinned distributionUrl
- [ ] #2 The regenerated wrapper jar matches the checksum published by Gradle for that version (record the sha256 in the PR/commit for provenance)
- [ ] #3 CI still builds (apk-build + native-tests jobs green) with the regenerated wrapper
- [ ] #4 Consider enabling Gradle wrapper validation (the gradle/wrapper-validation-action) in CI so a tampered/unknown wrapper jar is caught automatically
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-287 CI hotfixes c5d0c0d/f6b4532)
- Files: android/gradle/wrapper/gradle-wrapper.jar (53636 bytes), android/gradlew:154, android/gradlew.bat:52, android/gradle/wrapper/gradle-wrapper.properties (pins 8.11.1)
- Not a CI breaker (functional today); this is supply-chain/consistency hygiene
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
