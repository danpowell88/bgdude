---
id: TASK-204
title: Clean up partial model downloads; re-verify installed state
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:10'
updated_date: '2026-07-07 17:23'
labels:
  - code-health
  - "\U0001F9E0 llm"
milestone: m-8
dependencies: []
priority: low
ordinal: 111800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/panel_model_manager.dart:29-40` delegates the ~0.5 GB download to flutter_gemma with no partial-file handling; `_restore` (`lib/providers.dart:216-221`) trusts `isModelInstalled` blindly, and the `downloading` flag only resets via catch — not on process death.

**Reason for change.** A process death mid-download can leave a partial file that passes the installed check and then fails at load.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A persisted in-flight-download marker exists; on restore with the marker set, re-verify or delete before marking installed
- [x] #2 Load failure falls back to parser-only and clears installed
- [x] #3 Test with a truncated model file
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Persist an in-flight-download marker before starting the download and clear it on verified completion
- On restore with the marker set, re-verify the model (or delete the partial file) before marking installed
- Make load failure fall back to parser-only and clear the installed state
- Add a test using a truncated model file
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 9)
- Effort: S
- Where: `lib/panel_model_manager.dart:29-40`, `lib/providers.dart:216-221`
- Related: TASK-88 (integrity/gating), TASK-16
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 17:15
---
Started: reviewing PanelModelController's restore/download flow and flutter_gemma's isModelInstalled/installModel API to add an in-flight-download marker.
---

author: Claude
created: 2026-07-07 17:23
---
AC#1: added a persisted in-flight-download marker (panel_llm_downloading_v1) set to the target URL right before _mgr.download(...) starts and cleared in a finally block regardless of outcome. On _restore() at startup, a non-empty marker means the previous session died mid-download -- the partial file is deleted before ever trusting isInstalled (flutter_gemma's own isModelInstalled is documented as a bare file-existence check, so a partial file would otherwise pass it and only surface much later at actual inference time). Also clear any stale file for a URL right before EACH download attempt starts (flutter_gemma's own installModel() skips the download entirely if its internal isModelInstalled sees a same-named file already present -- a leftover truncated file from an earlier crash could otherwise make a retry silently 'complete' instantly over the bad file) and clean up the partial file on a failed download too, not just leave it. AC#2: GemmaPanelExtractor gained an onModelLoadFailed(Object) callback invoked specifically when FlutterGemma.getActiveModel() itself throws (as opposed to a later inference-time failure/timeout/OOM on an otherwise-good model, which must NOT clear installed) -- wired in panelLlmProvider to call the new PanelModelController.markLoadFailed() (clears installed + deletes the file). AC#3: made PanelModelManager injectable into PanelModelController (optional constructor param, defaults to the real one) and added test/panel_model_controller_test.dart with a _FakeModelManager double simulating a truncated/partial file (isInstalled reports true per a bare existence check while the in-flight marker says the download never confirmed) -- 4 tests covering the marker-triggers-cleanup restore path, a normal successful restore is unaffected, download() clears the marker on both success and failure paths (and cleans up the failed attempt's partial file), and markLoadFailed clears installed + deletes the file. Also test/panel_llm_test.dart: GemmaPanelExtractor's load-failure callback fires and extract() still returns null (falls back to the deterministic parser) -- FlutterGemma.getActiveModel() has no native LiteRT to load on this desktop test host, which conveniently exercises the exact same failure shape as a real corrupt/truncated file. flutter analyze clean, flutter test test/ green (983 tests), flutter build apk --debug succeeded. No native Kotlin/screen change -- DoD #5/#6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
