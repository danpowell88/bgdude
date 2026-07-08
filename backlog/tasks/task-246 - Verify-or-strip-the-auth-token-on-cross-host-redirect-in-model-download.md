---
id: TASK-246
title: Verify or strip the auth token on cross-host redirect in model download
status: Done
assignee:
  - Claude
created_date: '2026-07-07 13:28'
updated_date: '2026-07-08 04:35'
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
- [x] #1 Token is not forwarded to a non-allowlisted host after an HTTP redirect (verified, not assumed)
- [x] #2 If flutter_gemma cannot guarantee redirect stripping, the download is performed via a client under our control that strips Authorization on cross-host redirect
- [x] #3 www.huggingface.co accepted in the token allowlist alongside huggingface.co
- [x] #4 Test: token withheld after a simulated cross-host redirect
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-16)
- File: lib/food/panel_model_manager.dart token/allowlist path
- Related: TASK-88 (model integrity and gating), TASK-16 (SHA-256 AC still open)
- Distinct from SHA-256 (that is tracked by TASK-88 AC#1 and TASK-16 AC#3)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 04:23
---
Started: investigating panel_model_manager.dart's tokenForHost + FlutterGemma fromNetwork to determine whether the auth token can leak to a non-allowlisted host on a cross-host redirect (e.g. Hugging Face's gated-model CDN handoff), and fixing the www.huggingface.co allowlist gap.
---

author: Claude
created: 2026-07-08 04:35
---
All 4 ACs done with a real fix, not just added tests.

Root cause confirmed: flutter_gemma's fromNetwork(url, token:) hands the token to background_downloader's native platform downloader (Android DownloadManager / iOS URLSession under the hood), which follows redirects at the native/OS level -- outside Dart's control, and not something this app can inspect or override.

AC#1/#2: added PanelModelManager.resolveWithSafeRedirects -- manually follows redirects via an injectable http.Client (followRedirects: false per hop), re-evaluating tokenForHost against the CURRENT host at every hop, not just the first. download() now routes through this (then flutter_gemma's fromFile()) whenever a token would actually be sent; the common token-free case is unchanged (nothing to leak, keeps using fromNetwork()).

AC#3: added www.huggingface.co to tokenAllowedHosts alongside the bare host.

AC#4: 3 new tests in test/panel_model_manager_test.dart using http/testing.dart's MockClient -- (1) a redirect from huggingface.co to cdn-lfs.huggingface.co correctly withholds the token on the second hop, (2) a redirect that stays within the allowlist (huggingface.co -> www.huggingface.co) correctly keeps the token, (3) an unbounded redirect chain throws rather than looping forever.

Rigor check: temporarily made the redirect loop always send the token regardless of host (bypassing tokenForHost) -- the new test correctly failed with the exact leak scenario AC#1 describes. Reverted; git diff clean.

Verified: flutter analyze clean, flutter test --coverage green (1164 tests, 67.44% >= 65% floor), flutter build apk --debug succeeds. No native Kotlin, no user-guide update (internal security hardening, no user-visible surface change).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
