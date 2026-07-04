/// A unified view of "the current day" — the CGM history, insulin/carb events, therapy
/// settings, and health context — that the timeline, analytics, and prediction screens
/// all read from. In dev mode it comes from the simulator; in real mode it is assembled
/// from the encrypted store + live snapshot (history wiring lands with the drift
/// repositories; until then real mode yields just the live reading).
library;

import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../ml/sensitivity_model.dart';

class DayData {
  const DayData({
    required this.start,
    required this.end,
    required this.cgm,
    required this.boluses,
    required this.basal,
    required this.carbs,
    required this.settings,
    required this.context,
    required this.isSimulated,
  });

  final DateTime start;
  final DateTime end;
  final List<CgmSample> cgm;
  final List<BolusEvent> boluses;
  final List<BasalSegment> basal;
  final List<CarbEntry> carbs;
  final TherapySettings settings;
  final ContextFeatures? context;
  final bool isSimulated;

  bool get hasHistory => cgm.length > 1;

  CgmSample? get latest => cgm.isEmpty ? null : cgm.last;

  double? recentRocMgdlPerMin() {
    if (cgm.length < 2) return null;
    final a = cgm[cgm.length - 2];
    final b = cgm.last;
    final mins = b.time.difference(a.time).inMinutes;
    if (mins <= 0) return null;
    return (b.mgdl - a.mgdl) / mins;
  }

  static DayData empty(TherapySettings settings) => DayData(
        start: DateTime.now(),
        end: DateTime.now(),
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        context: null,
        isSimulated: false,
      );
}
