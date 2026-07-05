/// Lab HbA1c entries and their discordance with the CGM-derived GMI. Some people's
/// glycation systematically runs higher or lower than their average glucose predicts (a
/// "glycation gap"), so a lab A1c that disagrees with GMI is worth surfacing — targets set
/// on one may mislead against the other.
library;

import 'dart:convert';

import '../data/kv_store.dart';

class LabA1c {
  const LabA1c({required this.percent, required this.date});
  final double percent;
  final DateTime date;

  Map<String, dynamic> toJson() =>
      {'percent': percent, 'date': date.toIso8601String()};

  factory LabA1c.fromJson(Map<String, dynamic> j) => LabA1c(
        percent: (j['percent'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
      );
}

/// The gap between a lab A1c and the concurrent CGM-derived GMI.
class GlycationGap {
  const GlycationGap({required this.labPercent, required this.gmiPercent});
  final double labPercent;
  final double gmiPercent;

  /// Lab − GMI. Positive = lab runs higher than the CGM average predicts.
  double get gapPercent => labPercent - gmiPercent;

  /// A gap this large or more can meaningfully shift how a target is interpreted.
  bool get significant => gapPercent.abs() >= 0.5;

  String get message {
    final lab = labPercent.toStringAsFixed(1);
    final gmi = gmiPercent.toStringAsFixed(1);
    final mag = gapPercent.abs().toStringAsFixed(1);
    if (!significant) {
      return 'Your lab A1c ($lab%) and CGM-derived GMI ($gmi%) agree within 0.5%.';
    }
    return gapPercent > 0
        ? 'Your lab A1c ($lab%) runs ~$mag% higher than your CGM GMI ($gmi%) — a '
            'GMI-based target may understate your lab result. Discuss with your team.'
        : 'Your lab A1c ($lab%) runs ~$mag% lower than your CGM GMI ($gmi%) — your '
            'lab result may look better than your average glucose suggests.';
  }
}

class LabA1cStore {
  static const _key = 'lab_a1c_v1';
  static const _max = 50;

  static Future<List<LabA1c>> load() async {
    final raw = await KvStore.getString(_key);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return [for (final e in list) LabA1c.fromJson(e)]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static Future<void> add(LabA1c entry) async {
    final all = [...await load(), entry]
      ..sort((a, b) => a.date.compareTo(b.date));
    final capped = all.length > _max ? all.sublist(all.length - _max) : all;
    await KvStore.setString(
        _key, jsonEncode([for (final e in capped) e.toJson()]));
  }
}
