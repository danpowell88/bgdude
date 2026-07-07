---
id: TASK-246
title: Verify or strip the auth token on cross-host redirect in model download
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 13:28'
labels: []
milestone: m-4
dependencies: []
priority: medium
ordinal: 510000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In panel_model_manager.dart tokenForHost correctly gates the auth token on the initial URL host (host-equality, robust against subdomain/userinfo/case tricks). But the token is handed to FlutterGemma fromNetwork(url, token) which follows redirects internally. Gated Hugging Face model URLs routinely 302 to a CDN host (cdn-lfs.huggingface.co, CloudFront/S3) not in the allowlist; whether the Authorization header is stripped on that cross-host redirect is up to flutter_gemma HTTP client and is neither controlled nor verified here. So the token-withheld-from-non-allowlisted-hosts guarantee holds only for the first hop. Also: the allowlist accepts www.kaggle.com but only bare huggingface.co, so a www.huggingface.co gated URL silently loses its token.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Token is not forwarded to a non-allowlisted host after an HTTP redirect (verified, not assumed)
- [ ] #2 If flutter_gemma cannot guarantee redirect stripping, the download is performed via a client under our control that strips Authorization on cross-host redirect
- [ ] #3 www.huggingface.co accepted in the token allowlist alongside huggingface.co
- [ ] #4 Test: token withheld after a simulated cross-host redirect
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-16)
- File: lib/food/panel_model_manager.dart token/allowlist path
- Related: TASK-88 (model integrity and gating), TASK-16 (SHA-256 AC still open)
- Distinct from SHA-256 (that is tracked by TASK-88 AC#1 and TASK-16 AC#3)
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
