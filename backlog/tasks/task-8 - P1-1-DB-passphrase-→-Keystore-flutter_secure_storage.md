---
id: TASK-8
title: DB passphrase → Keystore (flutter_secure_storage)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:07'
labels:
  - roadmap
  - security
  - detail-needed
milestone: m-0
dependencies: []
priority: high
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude stores your data in an encrypted database. The encryption key (a passphrase) is meant to be protected by the Android Keystore (secure hardware), and the code comments and README say it is. In reality the passphrase sits in plain text in ordinary app settings storage, right next to the encrypted file.

**Reason for change.** Anyone who can read the app's files also gets the key, so the "encryption at rest" is effectively for show — and the false "Keystore" claims make it worse by implying protection that is not there. This is health data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Passphrase stored via flutter_secure_storage/Keystore
- [ ] #2 Migrated off SharedPreferences
- [ ] #3 Write awaited before DB open
- [ ] #4 False security comments corrected
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Move the passphrase to `flutter_secure_storage` (Android Keystore).
- Migrate any existing prefs value across on first run.
- Await the write before opening the DB (`secure_key.dart`, `database.dart:187`, `main.dart`).
- Correct the misleading comments/README.
- Test the migration path (prefs → secure storage) and that the DB opens with the migrated key; verify the passphrase is absent from prefs afterward. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-1 (headline issue #2)
- Effort: S
- Where: `secure_key.dart`, `database.dart:187`, `main.dart`
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): Security-critical (the DB encryption key): wants your go-ahead to add the flutter_secure_storage dependency + the exact prefs->Keystore migration strategy, since a bad migration would lock you out of the existing encrypted DB.
---
<!-- COMMENTS:END -->
