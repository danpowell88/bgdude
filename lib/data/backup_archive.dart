/// Encrypted full-data backup and restore (issue #170).
///
/// **The archive is itself a SQLCipher database**, produced by SQLCipher's own
/// `sqlcipher_export()` into a file keyed by a passphrase you choose. That is a deliberate
/// choice over inventing an archive format encrypted with a bolted-on cipher library:
/// this app's data is already protected by SQLCipher, it is already vetted and shipped,
/// and adding a second crypto stack to a health app means two things to keep patched and
/// two ways to get it wrong. It also means the backup carries the DB and the KV blobs
/// together without any special handling — the KV store is a table in the same database.
///
/// Everything in this file is pure: the manifest and, more importantly, the decision about
/// whether a given archive may be restored. The actual cipher calls live behind
/// [BackupIo] so that decision is testable without a device.
library;

import 'dart:convert';

/// What an archive says about itself. Written into the archive as a `backup_meta` row.
class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.createdAtEpochMs,
    this.appVersion = '',
  });

  /// Version of the ARCHIVE format (this file), independent of the database schema.
  /// Bumped only if the envelope itself changes shape.
  final int formatVersion;

  /// `AppDatabase.schemaVersion` at the time of export. The field the restore check
  /// turns on.
  final int schemaVersion;

  final int createdAtEpochMs;
  final String appVersion;

  static const int currentFormatVersion = 1;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtEpochMs);

  String encode() => jsonEncode({
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'createdAtEpochMs': createdAtEpochMs,
        'appVersion': appVersion,
      });

  /// Returns null for anything unreadable rather than throwing — a corrupt or
  /// non-bgdude file must produce a clear refusal, not a crash mid-restore.
  static BackupManifest? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final format = json['formatVersion'];
      final schema = json['schemaVersion'];
      final created = json['createdAtEpochMs'];
      if (format is! int || schema is! int || created is! int) return null;
      return BackupManifest(
        formatVersion: format,
        schemaVersion: schema,
        createdAtEpochMs: created,
        appVersion: (json['appVersion'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Why a restore was refused.
enum RestoreRefusal {
  /// The file isn't a bgdude archive, or the passphrase was wrong (indistinguishable —
  /// a wrong key makes SQLCipher see gibberish, not a recognisable file).
  unreadable,

  /// Written by a NEWER app version than this one. Restoring would put a database this
  /// build cannot read (or would silently downgrade) in place of a working one.
  fromNewerSchema,

  /// Written by an OLDER schema. Restorable in principle, but only by running the
  /// migrations, which this path does not do.
  fromOlderSchema,

  /// The archive envelope itself is a format this build doesn't know.
  unknownFormat,
}

/// The decision about whether [manifest] may be restored onto a build at
/// [currentSchemaVersion].
///
/// Deliberately refuses BOTH directions of schema mismatch rather than only the newer one.
/// A newer archive obviously can't be read. An older one is the subtler hazard: it would
/// open, appear to work, and then be migrated in place — turning a backup into a one-way
/// upgrade of the very copy the user was keeping as a fallback. Restoring an old archive
/// is a real feature, but it is a migration feature, and pretending otherwise is how
/// people lose data.
typedef RestoreVerdict = ({bool allowed, RestoreRefusal? refusal});

RestoreVerdict checkRestore(
  BackupManifest? manifest, {
  required int currentSchemaVersion,
}) {
  if (manifest == null) {
    return (allowed: false, refusal: RestoreRefusal.unreadable);
  }
  if (manifest.formatVersion != BackupManifest.currentFormatVersion) {
    return (allowed: false, refusal: RestoreRefusal.unknownFormat);
  }
  if (manifest.schemaVersion > currentSchemaVersion) {
    return (allowed: false, refusal: RestoreRefusal.fromNewerSchema);
  }
  if (manifest.schemaVersion < currentSchemaVersion) {
    return (allowed: false, refusal: RestoreRefusal.fromOlderSchema);
  }
  return (allowed: true, refusal: null);
}

/// User-facing explanation of a refusal. Says what went wrong AND what to do, because
/// "restore failed" on the one copy of someone's health history is not an acceptable
/// place to stop.
String restoreRefusalMessage(RestoreRefusal refusal) => switch (refusal) {
      RestoreRefusal.unreadable =>
        "Couldn't read that backup. Either the passphrase is wrong or the file isn't a "
            'bgdude backup — a wrong passphrase looks identical to a damaged file, so '
            'check the passphrase first.',
      RestoreRefusal.fromNewerSchema =>
        'That backup was made by a newer version of bgdude than this one. Update the '
            'app first — restoring it here would replace your data with something this '
            'build cannot read.',
      RestoreRefusal.fromOlderSchema =>
        'That backup was made by an older version of bgdude. It can be restored, but '
            'it has to be migrated first — this build will not do that silently, '
            'because it would permanently upgrade the backup you were keeping as a '
            'fallback.',
      RestoreRefusal.unknownFormat =>
        "That backup uses an archive format this build doesn't recognise.",
    };

/// The cipher/filesystem operations a backup needs. Behind an interface because they
/// require a real SQLCipher runtime, which unit tests on a desktop host do not have.
abstract interface class BackupIo {
  /// Export the live database into [path], encrypted with [passphrase], writing
  /// [manifest] into it.
  Future<void> exportTo(String path, String passphrase, BackupManifest manifest);

  /// Read the manifest out of an archive. Returns null when the file can't be opened
  /// with [passphrase] at all.
  Future<BackupManifest?> readManifest(String path, String passphrase);

  /// Replace the live database with the archive's contents.
  ///
  /// Implementations MUST leave the previous database recoverable — see
  /// `retireDatabaseFile`, which renames rather than deletes.
  Future<void> importFrom(String path, String passphrase);
}

/// Orchestrates export and restore. Holds no cipher code of its own.
class BackupService {
  const BackupService({required this.io, required this.currentSchemaVersion});

  final BackupIo io;
  final int currentSchemaVersion;

  /// Writes an encrypted archive to [path]. [now] is injected so the manifest is
  /// deterministic in tests.
  Future<BackupManifest> export({
    required String path,
    required String passphrase,
    required DateTime now,
    String appVersion = '',
  }) async {
    final manifest = BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      schemaVersion: currentSchemaVersion,
      createdAtEpochMs: now.millisecondsSinceEpoch,
      appVersion: appVersion,
    );
    await io.exportTo(path, passphrase, manifest);
    return manifest;
  }

  /// Inspects an archive without changing anything — what a confirmation screen should
  /// call before offering to overwrite the user's data.
  Future<RestoreVerdict> inspect({
    required String path,
    required String passphrase,
  }) async {
    BackupManifest? manifest;
    try {
      manifest = await io.readManifest(path, passphrase);
    } catch (_) {
      // A wrong passphrase surfaces as a failure to open, not a distinguishable error.
      manifest = null;
    }
    return checkRestore(manifest, currentSchemaVersion: currentSchemaVersion);
  }

  /// Restores [path] over the live database, but only after [inspect] allows it.
  ///
  /// Re-checks rather than trusting the caller: this is the one operation in the app
  /// that destroys data, and a UI that forgot to check must not be able to trigger it.
  Future<RestoreVerdict> restore({
    required String path,
    required String passphrase,
  }) async {
    final verdict = await inspect(path: path, passphrase: passphrase);
    if (!verdict.allowed) return verdict;
    await io.importFrom(path, passphrase);
    return verdict;
  }
}
