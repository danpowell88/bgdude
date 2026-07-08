---
id: TASK-300
title: >-
  Model-download redirect must not send the auth token over a cleartext HTTP
  downgrade
status: Done
assignee:
  - Claude
created_date: '2026-07-08 05:27'
updated_date: '2026-07-08 05:34'
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
- [x] #1 The redirect loop re-validates the scheme per hop and never attaches the Authorization token unless the current hop is https
- [x] #2 A downgrade redirect (allowlisted host but http scheme) either drops the token or aborts the download, not sends the bearer token over cleartext
- [x] #3 Test: a 30x to http://<allowlisted-host>/... asserts no Authorization header is sent on that hop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-246 fix (df239d8)
- File: lib/food/panel_model_manager.dart resolveWithSafeRedirects :114-135, tokenForHost :48, validateHttps :38/:83
- One-line-ish fix: check current.scheme == https (reuse validateHttps) before attaching the header in the loop
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 05:30
---
Started: fixing resolveWithSafeRedirects to re-validate the scheme (not just host) per hop, so an https-to-http downgrade redirect never carries the token.
---

author: Claude
created: 2026-07-08 05:34
---
Fixed all 3 ACs with a minimal, single-point fix.

AC#1/#2: tokenForHost is the single gatekeeper already called both at the initial request (download()) and per-hop inside resolveWithSafeRedirects (TASK-246) -- added && uri.scheme == https to its condition, so fixing it in ONE place closes the gap everywhere it's checked, no changes needed to the redirect loop itself. A redirect that downgrades an allowlisted host to http:// now has the token withheld (dropped, not aborted -- matching the existing design philosophy already documented on tokenAllowedHosts: a token-free download from an untrusted/unencrypted destination is still safe to attempt).

AC#3: added a tokenForHost unit test (http scheme on an otherwise-allowlisted host -> null) and a resolveWithSafeRedirects integration test simulating a real https-to-http downgrade redirect via MockClient, asserting no Authorization header on the downgraded hop.

Rigor check: reverted tokenForHost to the host-only check -- both new tests correctly failed (token leaked in both the unit and integration test). Reverted; git diff clean.

Verified: flutter analyze clean, flutter test --coverage green (1183 tests, 67.85% >= 65% floor). flutter build apk --debug succeeds. No native Kotlin, no user-guide update (internal security hardening).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
