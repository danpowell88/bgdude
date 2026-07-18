/// Encrypted backup and restore (issue #170).
///
/// The passphrase is chosen here and never stored: an archive whose key sat next to it on
/// the same device would not be protecting anything. That also means a forgotten
/// passphrase is unrecoverable, which the screen says plainly rather than discovering
/// later.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_controller.dart';
import '../state/providers.dart';
import 'widgets/backup_view.dart';

/// Backups written by this device, newest first.
Future<List<File>> localBackups() async {
  final dir = await getApplicationDocumentsDirectory();
  final files = <File>[];
  await for (final entity in dir.list()) {
    if (entity is File &&
        entity.path.endsWith(BackupController.backupSuffix)) {
      files.add(entity);
    }
  }
  files.sort((a, b) => b.path.compareTo(a.path));
  return files;
}

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({
    super.key,
    this.controllerOverride,
    this.listBackups,
    this.shareFile,
  });

  /// Test seams. In production all three are null and the real controller,
  /// path_provider listing and share sheet are used — none of which exist on a unit
  /// test host, which is why the seams are here rather than the logic being untested.
  final BackupController? controllerOverride;
  final Future<List<BackupEntry>> Function()? listBackups;
  final Future<void> Function(String path)? shareFile;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _passphrase = TextEditingController();
  List<BackupEntry> _backups = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The export/restore buttons enable on a non-empty passphrase, so typing has to
    // trigger a rebuild.
    _passphrase.removeListener(_onPassphraseChanged);
    _passphrase.addListener(_onPassphraseChanged);
  }

  void _onPassphraseChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final found = widget.listBackups != null
        ? await widget.listBackups!()
        : [
            for (final f in await localBackups())
              BackupEntry(
                name: f.uri.pathSegments.last,
                sizeBytes: f.lengthSync(),
              ),
          ];
    if (!mounted) return;
    setState(() => _backups = found);
  }

  /// Full path of a listed backup. Entries carry only a name so the view stays free of
  /// dart:io; the directory is the app's own documents folder.
  Future<String> _pathFor(BackupEntry entry) async =>
      '${(await getApplicationDocumentsDirectory()).path}/${entry.name}';

  BackupController get _controller =>
      widget.controllerOverride ??
      BackupController(
        service: ref.read(backupServiceProvider),
        directoryPath: () async =>
            (await getApplicationDocumentsDirectory()).path,
        now: DateTime.now,
      );

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await _controller.export(_passphrase.text);
    if (result.outcome == BackupOutcome.exported && result.path != null) {
      await (widget.shareFile ?? _shareViaSheet)(result.path!);
      await _refresh();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _shareViaSheet(String path) => SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'bgdude encrypted backup'),
      );

  Future<void> _restore(BackupEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = widget.controllerOverride != null
        ? entry.name
        : await _pathFor(entry);
    if (!mounted) return;

    // Look before offering to overwrite: a refusal must be reported without anything
    // having been touched.
    setState(() => _busy = true);
    final check = await _controller.inspect(path, _passphrase.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (check.outcome != BackupOutcome.restored) {
      messenger.showSnackBar(SnackBar(
        content: Text(check.message),
        duration: const Duration(seconds: 8),
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
            'This replaces everything currently in the app with the contents of the '
            'backup. A copy of your current data is saved first, under the same '
            'passphrase, so this can be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              key: const Key('backup-confirm-restore'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await _controller.restore(path, _passphrase.text);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: BackupView(
        passphraseController: _passphrase,
        backups: _backups,
        busy: _busy,
        onExport: _export,
        onRestore: _restore,
      ),
    );
  }
}
