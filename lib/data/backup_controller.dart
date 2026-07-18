/// Export/restore orchestration for the backup screen (issue #170).
///
/// Separated from the screen so the sequencing — inspect before touching anything, refuse
/// with a reason, only then overwrite — is testable without path_provider, the share
/// sheet or a SQLCipher runtime. That sequencing is the part where a mistake costs
/// someone their history, so it should not only be reachable through a widget.
library;

import 'backup_archive.dart';

/// What happened, for the screen to turn into a message.
enum BackupOutcome {
  exported,
  restored,

  /// Refused before anything was modified — [BackupResult.refusal] says why.
  refused,

  /// The operation threw; nothing is guaranteed about how far it got, so the message
  /// must not claim success.
  failed,

  /// No passphrase, or no database open yet.
  notReady,
}

class BackupResult {
  const BackupResult(this.outcome, {this.refusal, this.path, this.error});

  final BackupOutcome outcome;
  final RestoreRefusal? refusal;

  /// Where the archive was written, for handing to the share sheet.
  final String? path;
  final Object? error;

  /// The message to show. A refusal explains what to do next; a failure never
  /// implies the operation succeeded.
  String get message => switch (outcome) {
        BackupOutcome.exported =>
          'Backup written. Keep the passphrase safe — it cannot be recovered.',
        BackupOutcome.restored =>
          'Restored. Restart the app to load the restored data.',
        BackupOutcome.refused => restoreRefusalMessage(refusal!),
        BackupOutcome.failed => 'That did not complete: $error',
        BackupOutcome.notReady =>
          'Enter a passphrase first (and wait for the app to finish loading).',
      };
}

/// Drives [BackupService] for the UI.
class BackupController {
  const BackupController({
    required this.service,
    required this.directoryPath,
    required this.now,
  });

  /// Null when the database has not opened — every entry point checks it.
  final BackupService? service;

  /// Where archives are written. Injected so tests don't need path_provider.
  final Future<String> Function() directoryPath;
  final DateTime Function() now;

  static const String backupSuffix = '.bgdude-backup';

  /// Filename for an archive created at [at].
  ///
  /// The timestamp is zero-padded so a plain lexicographic sort of the directory
  /// listing is also chronological. Unpadded epoch millis only sort correctly while
  /// every value happens to have the same number of digits — true for real dates, but
  /// a silent trap the moment it isn't.
  static String fileNameFor(DateTime at) =>
      'bgdude-${at.millisecondsSinceEpoch.toString().padLeft(13, '0')}'
      '$backupSuffix';

  Future<BackupResult> export(String passphrase) async {
    final svc = service;
    if (svc == null || passphrase.trim().isEmpty) {
      return const BackupResult(BackupOutcome.notReady);
    }
    try {
      final at = now();
      final path = '${await directoryPath()}/${fileNameFor(at)}';
      await svc.export(path: path, passphrase: passphrase, now: at);
      return BackupResult(BackupOutcome.exported, path: path);
    } catch (e) {
      return BackupResult(BackupOutcome.failed, error: e);
    }
  }

  /// Checks an archive WITHOUT modifying anything — what the confirmation step calls.
  Future<BackupResult> inspect(String path, String passphrase) async {
    final svc = service;
    if (svc == null || passphrase.trim().isEmpty) {
      return const BackupResult(BackupOutcome.notReady);
    }
    try {
      final verdict = await svc.inspect(path: path, passphrase: passphrase);
      return verdict.allowed
          ? const BackupResult(BackupOutcome.restored)
          : BackupResult(BackupOutcome.refused, refusal: verdict.refusal);
    } catch (e) {
      return BackupResult(BackupOutcome.failed, error: e);
    }
  }

  /// Performs the restore. Callers must have shown a confirmation first; the service
  /// re-checks regardless, so a caller that forgot cannot destroy anything.
  Future<BackupResult> restore(String path, String passphrase) async {
    final svc = service;
    if (svc == null || passphrase.trim().isEmpty) {
      return const BackupResult(BackupOutcome.notReady);
    }
    try {
      final verdict = await svc.restore(path: path, passphrase: passphrase);
      return verdict.allowed
          ? const BackupResult(BackupOutcome.restored)
          : BackupResult(BackupOutcome.refused, refusal: verdict.refusal);
    } catch (e) {
      return BackupResult(BackupOutcome.failed, error: e);
    }
  }
}
