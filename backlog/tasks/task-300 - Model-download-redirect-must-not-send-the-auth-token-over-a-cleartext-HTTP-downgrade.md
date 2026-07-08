---
id: TASK-300
title: >-
  Model-download redirect must not send the auth token over a cleartext HTTP
  downgrade
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 05:27'
labels: []
milestone: m-4
dependencies: []
priority: high
ordinal: 118500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-246 closed the cross-host token-leak by taking over redirect-following (resolveWithSafeRedirects, followRedirects=false, per-hop host-equality check). But it re-validates only the HOST per hop, not the SCHEME. validateHttps runs once on the initial URL in download() (panel_model_manager.dart:83); inside the redirect loop (:114-135) current is reassigned via current.resolve(location) with no scheme check, and tokenForHost (:48) matches on uri.host only. Scenario: an allowlisted host (e.g. huggingface.co) returns Location: http://huggingface.co/model (scheme downgrade to cleartext). current becomes an http:// URI whose host is still allowlisted, so tokenForHost returns the token and Authorization: Bearer <token> is transmitted over unencrypted HTTP -- a real (if narrow) credential-exposure path a network attacker on the path could capture. Out of the cross-host scope TASK-246 targeted (that is fully fixed), so this is a residual, not a regression.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The redirect loop re-validates the scheme per hop and never attaches the Authorization token unless the current hop is https
- [ ] #2 A downgrade redirect (allowlisted host but http scheme) either drops the token or aborts the download, not sends the bearer token over cleartext
- [ ] #3 Test: a 30x to http://<allowlisted-host>/... asserts no Authorization header is sent on that hop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-246 fix (df239d8)
- File: lib/food/panel_model_manager.dart resolveWithSafeRedirects :114-135, tokenForHost :48, validateHttps :38/:83
- One-line-ish fix: check current.scheme == https (reuse validateHttps) before attaching the header in the loop
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
