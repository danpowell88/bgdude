---
name: Task
about: A unit of work for the agent pipeline (Idea → … → Done; stage = board #2 Status column, decision-15)
title: ''
---

- **Ordinal:** <!-- band 1 fixes/tests 100000+, band 2 finish-existing 500000+, band 3 net-new 700000+ -->
- **Depends on:** <!-- #issue refs, or remove this line -->

## Description

<!-- Outcome + why. Short paragraphs or bullets. -->

## Acceptance Criteria

- [ ] <!-- testable, user/behavior-level criteria -->

## Implementation Plan

<!-- numbered steps, one per line (groomer fills this in if you don't) -->

## Implementation Notes

- Source: <!-- where this came from -->

## Definition of Done

- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds (generated files are not committed)
- [ ] `flutter analyze` clean
- [ ] `flutter test --coverage test/` green
- [ ] Line coverage did not drop — at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] `flutter build apk --debug` succeeds (catches Android/Gradle/manifest breakage)
- [ ] `gradlew :app:testDebugUnitTest` green when native Kotlin changed
- [ ] `doc/user-guide.html` updated when the change is user-visible, with screenshots
- [ ] Integration test added or extended when a screen/flow changed
- [ ] Issue updated with comments (`implemented-by:` ending with a `friction:` line)
- [ ] Reviewed by a different agent than the implementer — a `reviewed-by:` comment is present and the PR was merged when the issue reached the `Reviewed` column
- [ ] Closed (`Done`) only after Summer verified the issue's human-verification batch (decision-12) — agents never close task issues
