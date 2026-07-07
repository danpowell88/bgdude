import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logging/app_log.dart';
import '../logging/crash_log.dart';

/// Read-only view of the on-device diagnostics log (TASK-38): the most recent entries from
/// the [AppLog] ring buffer, newest first. Errors are highlighted. "Copy" puts the whole
/// buffer on the clipboard for a bug report; "Clear" empties it. Nothing here leaves the
/// device on its own. The persisted last-crash record (TASK-187) is pinned on top when
/// present — it survives the process dying, so an overnight fatal error is visible here
/// the next morning.
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key, this.log, this.crashText});

  /// Injectable for tests; defaults to the shared instance.
  final AppLog? log;

  /// Test seam: pre-loaded crash record. Widget tests can't complete the real
  /// file read inside the fake-async zone; production leaves this null and the
  /// record loads from [CrashLog].
  final String? crashText;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  AppLog get _log => widget.log ?? AppLog.instance;

  String? _lastCrash;

  @override
  void initState() {
    super.initState();
    _lastCrash = widget.crashText;
    if (_lastCrash == null) {
      CrashLog.readLast().then((c) {
        if (mounted && c != null) setState(() => _lastCrash = c);
      });
    }
  }

  Widget _crashCard(ColorScheme cs) => Card(
        margin: const EdgeInsets.all(12),
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.bug_report_outlined, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Last crash (persisted)',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: cs.onErrorContainer)),
                ),
                IconButton(
                  icon: Icon(Icons.copy_all_outlined,
                      size: 18, color: cs.onErrorContainer),
                  tooltip: 'Copy crash',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: _lastCrash!));
                    messenger.showSnackBar(
                        const SnackBar(content: Text('Crash copied.')));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: cs.onErrorContainer),
                  tooltip: 'Dismiss',
                  onPressed: () {
                    unawaited(CrashLog.clear());
                    setState(() => _lastCrash = null);
                  },
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                _lastCrash!,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      );

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
      body: Column(children: [
        if (_lastCrash != null) _crashCard(cs),
        Expanded(
          child: entries.isEmpty
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
        ),
      ]),
    );
  }
}
