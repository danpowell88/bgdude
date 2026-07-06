import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logging/app_log.dart';

/// Read-only view of the on-device diagnostics log (TASK-38): the most recent entries from
/// the [AppLog] ring buffer, newest first. Errors are highlighted. "Copy" puts the whole
/// buffer on the clipboard for a bug report; "Clear" empties it. Nothing here leaves the
/// device on its own.
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key, this.log});

  /// Injectable for tests; defaults to the shared instance.
  final AppLog? log;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  AppLog get _log => widget.log ?? AppLog.instance;

  @override
  Widget build(BuildContext context) {
    final entries = _log.entries.reversed.toList(); // newest first
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy',
            onPressed: entries.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(
                        text: entries.map((e) => e.line).join('\n')));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Log copied.')));
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: entries.isEmpty
                ? null
                : () => setState(_log.clear),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    'No diagnostics yet. Errors that would otherwise be silent show up here.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                final isError =
                    e.level == LogLevel.error || e.level == LogLevel.warn;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isError ? Icons.error_outline : Icons.info_outline,
                    color: isError ? cs.error : cs.outline,
                    size: 18,
                  ),
                  title: Text('${e.tag}: ${e.message}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  subtitle: Text(
                    '${e.time.toIso8601String()}${e.error == null ? '' : '\n${e.error}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  isThreeLine: e.error != null,
                );
              },
            ),
    );
  }
}
