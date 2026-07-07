/// Persisted last-crash record (TASK-187). The in-memory [AppLog] ring buffer dies
/// with the process, so fatal errors overnight left no trace. Every uncaught error —
/// Dart zone/framework/platform, and the native handler in `CrashLogger.kt` — appends
/// to the SAME app-local file (`filesDir/last_crash.txt`; on Android
/// `getApplicationSupportDirectory()` and Kotlin `context.filesDir` are the same
/// directory), which the Developer log screen surfaces on next launch.
///
/// On-device only by design: nothing here leaves the phone.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CrashLog {
  static const String fileName = 'last_crash.txt';

  /// Keep the file from growing unbounded: past this size the old content is
  /// dropped before appending (the newest crash is the one that matters).
  static const int maxBytes = 64000;

  /// Test seam: where the crash file lives. Defaults to the app-support dir
  /// (Android: the same `filesDir` the native handler writes to).
  static Future<Directory> Function() directoryProvider =
      getApplicationSupportDirectory;

  static Future<File> _file() async =>
      File('${(await directoryProvider()).path}${Platform.pathSeparator}$fileName');

  /// Append one crash record. A last-resort sink must never throw.
  static Future<void> record(String source, Object error, StackTrace stack) async {
    try {
      final f = await _file();
      if (await f.exists() && await f.length() > maxBytes) await f.delete();
      await f.writeAsString(
        '=== ${DateTime.now().toIso8601String()} dart $source\n$error\n$stack\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  /// The persisted crash record(s), or null when there has been no crash.
  static Future<String?> readLast() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final content = await f.readAsString();
      return content.trim().isEmpty ? null : content;
    } catch (_) {
      return null;
    }
  }

  /// Dismiss the record (Developer screen "clear").
  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
