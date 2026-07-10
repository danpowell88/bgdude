---
id: TASK-313
title: Pin GitHub Actions to commit SHAs (21 CodeQL actions/unpinned-tag warnings)
status: To Do
assignee: []
created_date: '2026-07-10 14:11'
labels:
  - security
milestone: m-8
dependencies: []
priority: low
ordinal: 130000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CodeQL flags every `uses: owner/action@vN` reference as `actions/unpinned-tag` (21 warnings, medium/non-blocking): a tag can be moved to malicious code by a compromised action repo; pinning to a full commit SHA (with the tag as a trailing comment) removes that supply-chain surface.

- Scope: all workflows (`ci.yml`, `codeql.yml`, `emulator-tests.yml`).
- Keep a `# vN` comment on each pin so Dependabot/renovate-style bumps stay legible.
- Source: CodeQL alerts on main, 2026-07-11.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every third-party action in .github/workflows is pinned to a full commit SHA with the version as a comment
- [ ] #2 All CodeQL actions/unpinned-tag alerts are resolved on the branch; CI still green
<!-- AC:END -->

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
- [ ] #10 Reviewed by a different agent than the implementer -- a reviewed-by comment is present and the PR was merged when the task reached Reviewed
- [ ] #11 Done only after Summer verified the task's human-verification batch (decision-12) -- agents never set Done
<!-- DOD:END -->
