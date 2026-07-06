/// A tiny on-device log (TASK-38): a bounded in-memory ring buffer, no network, no disk.
///
/// The point is field-diagnosability — a swallowed error should leave a trace a user can
/// read on the Developer/Advanced screen, rather than vanishing. The buffer is capped so it
/// can never grow without bound; the oldest entries are evicted first.
///
/// House rule this enables: an error may be swallowed only if the operation is genuinely
/// optional AND the catch logs here. Never log PII or payload contents — tags + short
/// messages only.
library;

import 'dart:collection';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
  });

  final DateTime time;
  final LogLevel level;

  /// Short subsystem tag, e.g. "alerts", "startup", "pump".
  final String tag;
  final String message;

  /// Optional error/exception string (never a full payload).
  final String? error;

  String get line {
    final e = error == null ? '' : ' — $error';
    return '${time.toIso8601String()} [${level.name}] $tag: $message$e';
  }
}

/// Process-wide log ring buffer. A singleton so any layer can reach it without plumbing,
/// but [AppLog.new] is usable directly in tests for isolation.
class AppLog {
  AppLog({this.capacity = 500}) : _entries = ListQueue<LogEntry>();

  /// The shared instance used across the app.
  static final AppLog instance = AppLog();

  final int capacity;
  final ListQueue<LogEntry> _entries;

  /// Newest-last snapshot of the buffer.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  int get length => _entries.length;

  void record(LogLevel level, String tag, String message,
      {Object? error, DateTime? at}) {
    _entries.addLast(LogEntry(
      time: at ?? DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
    ));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  void debug(String tag, String message, {Object? error, DateTime? at}) =>
      record(LogLevel.debug, tag, message, error: error, at: at);
  void info(String tag, String message, {Object? error, DateTime? at}) =>
      record(LogLevel.info, tag, message, error: error, at: at);
  void warn(String tag, String message, {Object? error, DateTime? at}) =>
      record(LogLevel.warn, tag, message, error: error, at: at);
  void error(String tag, String message, {Object? error, DateTime? at}) =>
      record(LogLevel.error, tag, message, error: error, at: at);

  void clear() => _entries.clear();
}

/// Convenience: log to the shared instance. `appLog.error('tag', 'msg', error: e)`.
AppLog get appLog => AppLog.instance;
