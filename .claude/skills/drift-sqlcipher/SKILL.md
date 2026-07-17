---
name: drift-sqlcipher
description: Work with bgdude's encrypted local database — drift ORM over SQLCipher (AES-256 at rest). Use when adding or changing tables/columns, writing migrations, touching the DB passphrase/Keystore handling, or debugging DB open/recovery failures. Covers the codegen step, the schema-version guards, and the key-management failure modes that must not be papered over.
---

# drift + SQLCipher (the encrypted local store)

All health/pump data lives in `lib/data/database.dart` (`AppDatabase`), AES-256 encrypted at
rest via SQLCipher. Tables are timestamp-indexed for the analytics engine's range scans.

## Codegen is mandatory (and mostly not committed)
The schema/query code is generated. After any table/column/query change:

```
dart run build_runner build --delete-conflicting-outputs
```

`lib/data/database.g.dart` is the **one** generated file committed to the repo — regenerate
and commit it with your schema change. Everything else drift generates is not committed, so
analyze/test/build depend on codegen succeeding (see `verify-build`).

## Schema changes → bump `schemaVersion` and add a migration
- Bump `AppDatabase.schemaVersion` and add the `if (from < N)` step in `onUpgrade`.
- New columns need a default (`withDefault(...)`) or a backfill — existing rows must remain
  valid. Match the existing tables' `@DataClassName`, `uniqueKeys`, and default conventions.
- **Downgrades are guarded**: drift's `onUpgrade` runs for downgrades too (no `onDowngrade`
  in this version). Opening a DB whose on-disk version is *newer* than this build throws
  `DatabaseDowngradeException` rather than silently stamping the version down and corrupting
  the marker. Don't remove that guard.

## Key management — do not paper over failures (`lib/data/secure_key.dart`)
- The SQLCipher passphrase (`db_passphrase_v1`) is generated once and stored in
  Keystore-backed `flutter_secure_storage`; reading the app's files alone doesn't yield it.
- A plain-store marker records that a key was ever generated. If secure storage returns no
  passphrase **but** the marker is set, that's a transient Keystore read failure (common
  after OS updates / device restores / biometric changes) → throw `SecureKeyReadFailure`,
  a distinct **retryable** error. Never silently generate a fresh key in that case — it
  orphans the still-intact encrypted DB under the old, now-unreachable key.

## Debugging open/recovery
`lib/data/db_open_diagnosis.dart` classifies open failures; `lib/ui/db_recovery_screen.dart`
is the recovery UI. Distinguish "wrong key / transient" (retryable) from "genuinely corrupt"
before offering a reset — a reset is data loss.
