---
id: TASK-8
title: DB passphrase → Keystore (flutter_secure_storage)
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:26'
labels:
  - roadmap
  - security
  - detail-needed
milestone: m-0
dependencies: []
priority: high
ordinal: 101900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude stores your data in an encrypted database. The encryption key (a passphrase) is meant to be protected by the Android Keystore (secure hardware), and the code comments and README say it is. In reality the passphrase sits in plain text in ordinary app settings storage, right next to the encrypted file.

**Reason for change.** Anyone who can read the app's files also gets the key, so the "encryption at rest" is effectively for show — and the false "Keystore" claims make it worse by implying protection that is not there. This is health data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Passphrase stored via flutter_secure_storage/Keystore
- [x] #2 Migrated off SharedPreferences
- [x] #3 Write awaited before DB open
- [x] #4 False security comments corrected
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

Implemented. AC#1: SecureKeyStore now stores the SQLCipher passphrase in flutter_secure_storage (AndroidOptions(encryptedSharedPreferences: true) — Keystore-backed); added the dependency. AC#2: open() migrates a passphrase written by the old SharedPreferences impl into secure storage and removes it from prefs, so an existing encrypted DB stays readable (generating a new key would have bricked it). AC#3: open() is async and awaits the secure write before returning; both callers (main.dart, background_summary.dart) already await open() before opening the DB, and getOrCreatePassphrase() now just returns the resolved value. AC#4: the false 'swap SharedPreferences for flutter_secure_storage' scaffold comment is gone and the code now matches database.dart's 'stored in the platform keystore via flutter_secure_storage' claim. Test: test/secure_key_test.dart (stable key across opens; legacy migration preserves the key + clears prefs). pub get + build_runner, analyze clean, 543 tests green, APK builds with the native plugin.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): Security-critical (the DB encryption key): wants your go-ahead to add the flutter_secure_storage dependency + the exact prefs->Keystore migration strategy, since a bad migration would lock you out of the existing encrypted DB.
---
<!-- COMMENTS:END -->
