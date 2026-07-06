---
id: TASK-156
title: Encrypted full-data backup and restore
status: To Do
assignee: []
created_date: '2026-07-06 08:44'
labels:
  - feature
  - data-integrity
  - security
milestone: m-7
dependencies:
  - TASK-8
  - TASK-42
priority: medium
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The only export today is report PDF/CSV (`lib/reports/report_exporter.dart`); there is no way to move the app (DB, learned models, meal library, annotations, lab A1c, confirmation decisions) to a new phone — the biggest data-loss risk for an on-device-only tool. The DB is already encrypted (SecureKeyStore + `openEncryptedDatabase`) and the share-sheet path exists.

**Value.** Months of learned models and history survive a phone change or loss; today they do not.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One encrypted archive (passphrase-derived key) contains DB + KV blobs, exported via the share sheet
- [ ] #2 A restore path checks schema version and refuses cross-schema restore without migration
- [ ] #3 A round-trip test passes
- [ ] #4 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Define the archive format: DB file + KV blobs, encrypted with a passphrase-derived key.
- Implement export via the existing share-sheet path.
- Implement restore with a schema-version check refusing cross-schema restore without migration.
- Add a round-trip test.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/reports/report_exporter.dart`, SecureKeyStore)
- Effort: L
- Where: new backup service, settings screen entry, `doc/user-guide.html`
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
