/// The Confirmation Inbox model: detected-but-unconfirmed events the app surfaces for the
/// user to confirm, dismiss, or edit. Confirming writes an [Annotation] (feeding both the
/// reports' "confirmed" data tier and the training pipeline); dismissing records the
/// decision so the item doesn't resurface.
library;

import 'dart:convert';

import '../data/kv_store.dart';
import '../logging/app_log.dart';
import 'annotations.dart';

/// The kinds of events that can be queued for confirmation. Extensible — add a source in
/// `ConfirmationService` and a case here.
enum ConfirmationType { unannouncedMeal, compressionLow, illness, siteFailure }

extension ConfirmationTypeX on ConfirmationType {
  /// The annotation written when the user confirms this item.
  AnnotationKind get suggestedKind => switch (this) {
        ConfirmationType.unannouncedMeal => AnnotationKind.missedCarbs,
        ConfirmationType.compressionLow => AnnotationKind.compressionLow,
        ConfirmationType.illness => AnnotationKind.illness,
        ConfirmationType.siteFailure => AnnotationKind.siteFailure,
      };
}

class PendingConfirmation {
  const PendingConfirmation({
    required this.type,
    required this.start,
    required this.end,
    required this.title,
    required this.detail,
    required this.confidence,
    this.carbsGrams,
  });

  final ConfirmationType type;
  final DateTime start;
  final DateTime end;
  final String title;
  final String detail;

  /// Detector confidence 0..1, shown so the user can weigh borderline items.
  final double confidence;

  /// Estimated carbs for meal candidates (null otherwise).
  final double? carbsGrams;

  /// Stable identity: type + the 30-minute bucket of [start]. Re-scanning the same
  /// history yields the same id, so decisions dedupe reliably across scans.
  String get id {
    final bucket = start.millisecondsSinceEpoch ~/ (30 * 60 * 1000);
    return '${type.name}:$bucket';
  }

  AnnotationKind get suggestedKind => type.suggestedKind;
}

enum ConfirmationDecision { confirmed, dismissed }

/// Persisted record of which pending items the user has already decided on, so confirmed
/// and dismissed items don't reappear on the next scan. Capped to the most recent
/// [_maxEntries] decisions.
class ConfirmationDecisionStore {
  static const _key = 'confirmation_decisions_v1';
  static const _maxEntries = 1000;

  static Future<Map<String, ConfirmationDecision>> load() async {
    final raw = await KvStore.getString(_key);
    if (raw == null) return {};
    Map<String, dynamic> map;
    try {
      map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (e) {
      appLog.error('persistence', 'corrupt confirmation decisions — starting empty',
          error: e);
      return {};
    }
    final out = <String, ConfirmationDecision>{};
    for (final e in map.entries) {
      try {
        // TASK-206: a malformed entry (not a Map) must not lose every other
        // decision — skip just this one.
        final d = (e.value as Map)['d'] as String?;
        final decision = ConfirmationDecision.values
            .where((v) => v.name == d)
            .cast<ConfirmationDecision?>()
            .firstOrNull;
        if (decision != null) out[e.key] = decision;
      } catch (err) {
        appLog.error('persistence', 'skipped corrupt confirmation-decision entry',
            error: err);
      }
    }
    return out;
  }

  static Future<void> record(String id, ConfirmationDecision decision,
      {required DateTime at}) async {
    final raw = await KvStore.getString(_key);
    Map<String, dynamic> map;
    try {
      map = raw == null
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (e) {
      // TASK-206: a corrupt existing blob must not block recording a NEW decision
      // — start fresh rather than throw.
      appLog.error(
          'persistence', 'corrupt confirmation decisions — resetting on write',
          error: e);
      map = <String, dynamic>{};
    }
    map[id] = {'d': decision.name, 't': at.toIso8601String()};
    // Cap: keep the most recently decided entries.
    if (map.length > _maxEntries) {
      final entries = map.entries.toList()
        ..sort((a, b) => ((b.value as Map)['t'] as String)
            .compareTo((a.value as Map)['t'] as String));
      map
        ..clear()
        ..addEntries(entries.take(_maxEntries));
    }
    await KvStore.setString(_key, jsonEncode(map));
  }
}
