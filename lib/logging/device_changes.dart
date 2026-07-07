/// Tracks CGM sensor and infusion-site changes: when they were last changed, how old
/// they are, and when a change is due. Site age feeds the site-failure story ("insulin
/// looks weak and your site is 3 days old") and both surface as timeline events.
///
/// Persisted in shared_preferences (just the last-change timestamps + history).
library;

import 'dart:convert';

import '../data/kv_store.dart';
import 'app_log.dart';

enum DeviceKind { sensor, site }

extension DeviceKindX on DeviceKind {
  String get label => this == DeviceKind.sensor ? 'CGM sensor' : 'Infusion site';

  /// Typical wear duration before a change is recommended.
  Duration get typicalLife => this == DeviceKind.sensor
      ? const Duration(days: 10) // Dexcom G7 ~10 days
      : const Duration(days: 3); // infusion set ~3 days
}

class DeviceChange {
  const DeviceChange({required this.kind, required this.changedAt});
  final DeviceKind kind;
  final DateTime changedAt;

  Map<String, dynamic> toJson() =>
      {'kind': kind.name, 'changedAt': changedAt.toIso8601String()};

  /// TASK-206: throws (not a silent default) on a renamed/removed [DeviceKind]
  /// name or a malformed entry — [DeviceState.fromJson] catches this per entry
  /// and skips just that one, rather than losing the whole change history.
  factory DeviceChange.fromJson(Map<String, dynamic> j) {
    final kindName = j['kind'] as String?;
    final kind = DeviceKind.values.asNameMap()[kindName];
    if (kind == null) {
      throw FormatException('unknown DeviceKind "$kindName"');
    }
    return DeviceChange(
      kind: kind,
      changedAt: DateTime.parse(j['changedAt'] as String),
    );
  }
}

class DeviceState {
  const DeviceState({this.changes = const []});
  final List<DeviceChange> changes;

  DeviceChange? lastChange(DeviceKind kind) {
    final of = [for (final c in changes) if (c.kind == kind) c]
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return of.isEmpty ? null : of.first;
  }

  Duration? age(DeviceKind kind, DateTime now) {
    final last = lastChange(kind);
    return last == null ? null : now.difference(last.changedAt);
  }

  /// Fraction of typical life elapsed (>1 means overdue), or null if never logged.
  double? lifeFraction(DeviceKind kind, DateTime now) {
    final a = age(kind, now);
    if (a == null) return null;
    return a.inMinutes / kind.typicalLife.inMinutes;
  }

  bool isOverdue(DeviceKind kind, DateTime now) =>
      (lifeFraction(kind, now) ?? 0) >= 1.0;

  DeviceState withChange(DeviceChange change) =>
      DeviceState(changes: [...changes, change]);

  Map<String, dynamic> toJson() =>
      {'changes': [for (final c in changes) c.toJson()]};

  factory DeviceState.fromJson(Map<String, dynamic> j) {
    final changes = <DeviceChange>[];
    for (final c in (j['changes'] as List? ?? const [])) {
      try {
        changes.add(DeviceChange.fromJson((c as Map).cast<String, dynamic>()));
      } catch (err) {
        // TASK-206: one bad entry must not lose every other device change.
        appLog.error('persistence', 'skipped corrupt device-change entry', error: err);
      }
    }
    return DeviceState(changes: changes);
  }
}

class DeviceChangeStore {
  static const _key = 'device_changes_v1';

  static Future<DeviceState> load() async {
    final raw = await KvStore.getString(_key);
    if (raw == null) return const DeviceState();
    try {
      return DeviceState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      appLog.error('persistence', 'corrupt device-change store — starting empty',
          error: e);
      return const DeviceState();
    }
  }

  static Future<void> save(DeviceState state) async {
    await KvStore.setString(_key, jsonEncode(state.toJson()));
  }
}
