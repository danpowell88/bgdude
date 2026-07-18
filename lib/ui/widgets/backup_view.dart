/// The backup screen's presentation (issue #170), split out so its copy and its
/// enable/disable rules are testable without path_provider, the share sheet or a
/// SQLCipher runtime — none of which exist on a unit-test host.
library;

import 'package:flutter/material.dart';

/// One backup file as the view needs it: no dart:io, so tests don't need a filesystem.
class BackupEntry {
  const BackupEntry({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;

  String get sizeLabel => '${(sizeBytes / 1024).round()} KB';
}

class BackupView extends StatelessWidget {
  const BackupView({
    super.key,
    required this.passphraseController,
    required this.backups,
    required this.busy,
    required this.onExport,
    required this.onRestore,
  });

  final TextEditingController passphraseController;
  final List<BackupEntry> backups;
  final bool busy;
  final VoidCallback onExport;
  final void Function(BackupEntry) onRestore;

  /// Nothing can be exported or restored without a passphrase, and nothing at all
  /// while an operation is in flight — a second restore starting mid-restore would be
  /// a genuinely bad day.
  bool get _enabled => !busy && passphraseController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'A backup is a single encrypted file containing everything the app '
          'stores. It is locked with a passphrase you choose here.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('backup-passphrase'),
          controller: passphraseController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passphrase',
            border: OutlineInputBorder(),
            // Said up front, not discovered later.
            helperText: 'Never stored. If you forget it, the backup is '
                'unreadable — by anyone, including you.',
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('backup-export'),
          icon: const Icon(Icons.ios_share),
          label: const Text('Create backup & share'),
          onPressed: _enabled ? onExport : null,
        ),
        const SizedBox(height: 24),
        Text('Backups on this device', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (backups.isEmpty)
          Text('None yet.', style: theme.textTheme.bodySmall)
        else
          for (final b in backups)
            ListTile(
              key: Key('backup-entry-${b.name}'),
              dense: true,
              leading: const Icon(Icons.archive_outlined),
              title: Text(b.name),
              subtitle: Text(b.sizeLabel),
              trailing: TextButton(
                onPressed: _enabled ? () => onRestore(b) : null,
                child: const Text('Restore'),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          'To restore a backup from another device, share it to this phone first '
          'and save it into the app folder — bgdude lists what it finds there.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
