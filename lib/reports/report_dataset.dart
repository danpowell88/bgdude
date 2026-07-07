/// The one range-scoped fetch behind the Reports section (TASK-117). Each report
/// builder used to query the repository independently for the same range — a range
/// change re-ran every query and nothing was ever evicted. This value type holds
/// everything the builders need, fetched once.
///
/// The cgm/bolus/basal/carb lists extend [lookback] BEFORE `range.from` so the
/// therapy report can compute IOB at the range start; builders that want the exact
/// range use the `...InRange` getters, which replicate the repository's query
/// semantics (inclusive containment; basal by overlap).
library;

import '../core/samples.dart';
import '../data/health_sync.dart';
import '../feedback/annotations.dart';
import 'report_range.dart';

class ReportDataset {
  const ReportDataset({
    required this.range,
    required this.cgm,
    required this.boluses,
    required this.basal,
    required this.carbs,
    required this.health,
    required this.annotations,
  });

  /// How far before `range.from` the dosing lists extend (therapy IOB lookback).
  static const Duration lookback = Duration(hours: 6);

  final ReportRange range;

  /// Cover `[range.from - lookback, range.to]`.
  final List<CgmSample> cgm;
  final List<BolusEvent> boluses;
  final List<BasalSegment> basal;
  final List<CarbEntry> carbs;

  /// Cover the exact range.
  final List<HealthSample> health;
  final List<Annotation> annotations;

  bool _inRange(DateTime t) => !t.isBefore(range.from) && !t.isAfter(range.to);

  List<CgmSample> get cgmInRange =>
      [for (final s in cgm) if (_inRange(s.time)) s];

  List<BolusEvent> get bolusesInRange =>
      [for (final b in boluses) if (_inRange(b.time)) b];

  /// Repository semantics: segments OVERLAPPING the range.
  List<BasalSegment> get basalInRange => [
        for (final s in basal)
          if (!s.start.isAfter(range.to) && !s.end.isBefore(range.from)) s,
      ];

  List<CarbEntry> get carbsInRange =>
      [for (final c in carbs) if (_inRange(c.time)) c];
}
