# Decision 18 — the encrypted DB moves to `package:sqlite3` 3.x build hooks, **keeping SQLCipher**

- **Date:** 2026-07-19
- **Status:** proposed (needs Summer's on-device confirmation — see "What is not proven")
- **Context:** issue #354 — `sqlcipher_flutter_libs` was marked end-of-life

## Decision

Drop `sqlcipher_flutter_libs` entirely. Get the encrypted native library from
`package:sqlite3` 3.x's **build hook**, configured in `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlcipher
```

Dependencies move to `drift: ^2.34.0` and `sqlite3: ^3.4.0`.

## Why this option, and not SQLite3MultipleCiphers

The upstream maintainer's own guidance and drift's encryption page both steer new projects
toward **SQLite3MultipleCiphers** (`source: sqlite3mc`). We deliberately did **not** take that
option.

`sqlite3mc` *can* read a SQLCipher-created database, but only by issuing compatibility pragmas
before the key:

```
PRAGMA cipher = 'sqlcipher';
PRAGMA legacy = 4;
PRAGMA key = '…';
```

That is a real migration of a **live, encrypted, irreplaceable health database**, and drift's
own documentation warns to "carefully test that your app supports existing databases after
upgrading". `source: sqlcipher` keeps the **same cipher, the same on-disk format, and the same
`libsqlcipher.so`** — so there is nothing to migrate. The EOL problem is solved either way; only
one of the two options puts existing data at risk.

If SQLCipher is ever dropped from the hook options upstream, `sqlite3mc` is the fallback, and
that is when the pragma migration gets written and tested — not before.

## What changed in the code

- `open.overrideForAll(openCipherOnAndroid)` is **deleted** (both the main and the
  `isolateSetup` call). sqlite3 3.x resolves the native library through the hook, including in
  background isolates; the package "exclusively uses hooks now".
- The `PRAGMA key` + `PRAGMA cipher_version` guard in `openEncryptedDatabase` is unchanged — it
  still refuses to run against a non-SQLCipher library rather than silently storing plaintext.
- `SqliteException`'s constructor became named-argument in 3.x, and `resultCode` is now derived
  as `extendedResultCode & 0xFF`. That is a **behavioural improvement** for
  `classifyDbOpenFailure`: real extended codes such as `SQLITE_IOERR_READ` (266) now reduce to
  their primary code and classify correctly, where before they fell through to the catch-all.
  Pinned by a test.

## What was verified here

- `flutter pub get` resolves; `sqlcipher_flutter_libs` is gone from the lockfile.
- `flutter build apk --debug` succeeds, and the built APK contains **`libsqlcipher.so` for
  arm64-v8a, armeabi-v7a and x86_64**.
- That library is genuinely SQLCipher, not a renamed plain SQLite: it contains
  `sqlite3_key`, `cipher_version`, `cipher_page_size` and `PRAGMA cipher_store_pass`
  (SQLite 3.53.3 underneath).
- Full pipeline green: analyze, 1481 Dart tests, Kotlin unit tests, APK build, and
  `build_runner` regeneration produced no diff.

## What is **not** proven (issue #354 AC#5)

Nothing here opens a **pre-existing** encrypted database. The SQLCipher unit tests cannot run on
the Windows test host — `openCipherOnAndroid` needs a real device — so "existing data still
opens" rests on the argument that the cipher and on-disk format are unchanged, not on an
observation.

**Before this is trusted:** install over an existing install on the real device and confirm the
database opens with data intact. If it does not, the recovery screen's non-destructive path
handles it (the old file is renamed aside, never deleted), so the failure mode is recoverable —
but it must be checked, not assumed.
