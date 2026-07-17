/// TASK-192: the recovery flow for a failed database open — retry, salvage export
/// (when the key was confirmed correct so some tables may still be intact), and a
/// destructive, double-confirmed reset. Reached by tapping the storage-failed banner.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/db_open_diagnosis.dart';
import '../data/secure_key.dart';
import '../state/providers.dart';

class DbRecoveryScreen extends ConsumerStatefulWidget {
  const DbRecoveryScreen({super.key});

  @override
  ConsumerState<DbRecoveryScreen> createState() => _DbRecoveryScreenState();
}

class _DbRecoveryScreenState extends ConsumerState<DbRecoveryScreen> {
  bool _busy = false;

  String _title(DbOpenDiagnosis d) => switch (d) {
        DbOpenDiagnosis.keyOrHeaderCorrupt => 'Storage key mismatch or damage',
        DbOpenDiagnosis.corruptedData => 'Storage data damage',
        DbOpenDiagnosis.ioError => 'Storage couldn\'t be opened',
        DbOpenDiagnosis.keyReadFailure => 'Storage key temporarily unreadable',
        DbOpenDiagnosis.schemaNewerThanApp => 'App is older than your data',
        DbOpenDiagnosis.unknown => 'Storage problem',
      };

  String _explain(DbOpenDiagnosis d) => switch (d) {
        // TASK-249: no longer claims the data is unsalvageable — a key mismatch
        // (vs. genuine header corruption) is exactly the recoverable case this
        // ambiguity can hide, and "reset" now preserves the file rather than
        // erasing it either way.
        DbOpenDiagnosis.keyOrHeaderCorrupt =>
          'The saved key no longer matches the stored file, or the file itself is '
              'damaged beyond the point where it can even be identified as a '
              'database — this can happen after restoring a backup under a '
              'different key, or from file corruption. There\'s no way to '
              'distinguish the two from here. If you reset, the existing file is '
              'renamed aside rather than deleted, in case it turns out to be '
              'recoverable later.',
        DbOpenDiagnosis.corruptedData =>
          'The storage key checked out fine, but a deeper integrity check found '
              'damage. Some tables may still be intact — try exporting what\'s '
              'readable before resetting.',
        DbOpenDiagnosis.ioError =>
          'This looks like a filesystem problem (permissions, low storage) rather '
              'than damaged data — retrying may just work once the underlying '
              'issue clears.',
        DbOpenDiagnosis.keyReadFailure =>
          'The database file itself was never touched — only reading the saved key '
              'from secure storage failed, which is often a transient problem (for '
              'example right after an OS update). Try again first; only reset if '
              'retrying keeps failing.',
        DbOpenDiagnosis.schemaNewerThanApp =>
          'Your stored data was created by a newer version of bgdude than the one '
              'currently installed (for example after sideloading an older build). '
              'Nothing is damaged — install the version you were using before to '
              'get back to your data. Resetting storage here would permanently '
              'delete data that is otherwise perfectly intact, so it is not '
              'offered on this screen.',
        DbOpenDiagnosis.unknown =>
          'Storage failed to open for an unrecognised reason.',
      };

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      final keys = await SecureKeyStore.open();
      final result =
          await openHistoryRepository(keys.getOrCreatePassphrase());
      if (!mounted) return;
      if (result.diagnosis == null) {
        await result.db?.close();
        _showResult('Storage opened successfully — restart the app to use it.');
      } else {
        _showResult('Still failing: ${result.diagnosis!.name}. '
            'Export or reset below, or try again later.');
      }
    } catch (e) {
      if (mounted) _showResult('Retry failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSalvage(AppDatabase db) async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = await writeSalvageExportFile(db, directory: dir);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'bgdude salvage export',
      ));
    } catch (e) {
      if (mounted) _showResult('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetStorage() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset storage?'),
        content: const Text(
            'This makes every locally-stored reading, dose, meal, and learned model '
            'inaccessible to the app — a fresh, empty store is created in its place. '
            'The old file is kept renamed on disk rather than deleted, but there is '
            'no in-app undo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
            'Last check: this cannot be undone. Delete all local data now?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, delete everything'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await retireDatabaseFile();
      // TASK-249: only an explicit, twice-confirmed reset is allowed to clear the
      // read-failure marker — this is the one path where generating a brand new
      // key on the next open is actually what the user wants.
      await SecureKeyStore.forgetForReset();
      if (mounted) {
        _showResult('Storage reset — restart the app to start fresh.');
      }
    } catch (e) {
      if (mounted) _showResult('Reset failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = ref.watch(dbOpenDiagnosisProvider);
    final salvageDb = ref.watch(dbOpenSalvageDbProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage recovery')),
      body: diagnosis == null
          ? const Center(child: Text('Storage is fine — nothing to recover.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_title(diagnosis),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_explain(diagnosis)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry opening storage'),
                ),
                if (diagnosis.salvageable && salvageDb != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _exportSalvage(salvageDb),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Export what\'s still readable'),
                  ),
                ],
                // TASK-199: never offered for schemaNewerThanApp — the data isn't
                // corrupt, so this would only destroy intact, newer data.
                if (diagnosis.resetIsSensible) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: _busy ? null : _resetStorage,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Reset storage (destructive)'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }
}
