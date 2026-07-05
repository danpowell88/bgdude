/// Builds the sensitivity model's [ContextFeatures] from Health Connect samples.
///
/// "Today" values are the most recent readings (last night's sleep, overnight HRV,
/// morning resting HR, yesterday's exercise load); baselines are robust medians over a
/// longer window so the model reasons about *relative* change (HRV vs your baseline)
/// rather than absolute numbers, which vary hugely between people.
library;

import '../data/health_sync.dart';
import '../ml/sensitivity_model.dart';

class ContextBuilder {
  const ContextBuilder._();

  /// Returns null when there isn't enough health data to say anything useful.
  /// [menstrualLutealPhase] can be passed explicitly; otherwise it is inferred from
  /// Health Connect menstruation-flow records.
  static ContextFeatures? build({
    required List<HealthSample> today,
    required List<HealthSample> baseline,
    double? menstrualLutealPhase,
    double illnessFlag = 0,
    DateTime? now,
  }) {
    if (today.isEmpty && baseline.isEmpty) return null;
    final ref = now ?? DateTime.now();

    double? latest(List<HealthSample> src, String type) {
      final matching = [for (final s in src) if (s.type == type) s]
        ..sort((a, b) => a.time.compareTo(b.time));
      return matching.isEmpty ? null : matching.last.value;
    }

    double median(List<HealthSample> src, String type) {
      final vals = [for (final s in src) if (s.type == type) s.value]..sort();
      if (vals.isEmpty) return 0;
      final n = vals.length;
      return n.isOdd
          ? vals[n ~/ 2]
          : (vals[n ~/ 2 - 1] + vals[n ~/ 2]) / 2;
    }

    final sleepHours = latest(today, 'sleepHours') ?? 7.5;
    final sleepEfficiency = latest(today, 'sleepEfficiency') ?? 0.9;
    final hrv = latest(today, 'hrvRmssd') ?? median(baseline, 'hrvRmssd');
    final restingHr = latest(today, 'restingHr') ?? median(baseline, 'restingHr');

    // Yesterday's exercise load: total workout minutes in the last 36h, normalised
    // (~90 min of activity → full load).
    var exerciseMinutes = 0.0;
    for (final s in today) {
      if (s.type == 'exercise') exerciseMinutes += s.value;
    }
    final exerciseLoad = (exerciseMinutes / 90.0).clamp(0.0, 1.0);

    final baselineHrv = median(baseline, 'hrvRmssd');
    final baselineRestingHr = median(baseline, 'restingHr');

    // Extended signals.
    final respiratory = latest(today, 'respiratoryRate') ??
        median(baseline, 'respiratoryRate');
    final spo2 = latest(today, 'spo2') ?? median(baseline, 'spo2');
    final bodyTemp = latest(today, 'bodyTempC') ?? median(baseline, 'bodyTempC');
    var activeEnergy = 0.0;
    for (final s in today) {
      if (s.type == 'activeEnergyKcal') activeEnergy += s.value;
    }
    // Baseline active energy: median of per-day totals over the baseline window.
    final energyByDay = <DateTime, double>{};
    for (final s in baseline) {
      if (s.type != 'activeEnergyKcal') continue;
      final d = DateTime(s.time.year, s.time.month, s.time.day);
      energyByDay[d] = (energyByDay[d] ?? 0) + s.value;
    }
    final energyTotals = energyByDay.values.toList()..sort();
    final baselineEnergy = energyTotals.isEmpty
        ? 0.0
        : energyTotals[energyTotals.length ~/ 2];

    // Infer luteal phase from menstruation-flow records (roughly days 14–28 after the
    // most recent period start), unless the caller passed it explicitly.
    final luteal = menstrualLutealPhase ?? _lutealFromFlow([...today, ...baseline], ref);

    return ContextFeatures(
      sleepHours: sleepHours,
      sleepEfficiency: sleepEfficiency,
      overnightHrvRmssd: hrv,
      restingHr: restingHr,
      priorDayExerciseLoad: exerciseLoad,
      menstrualLutealPhase: luteal,
      illnessFlag: illnessFlag,
      baselineHrv: baselineHrv,
      baselineRestingHr: baselineRestingHr,
      overnightRespiratoryRate: respiratory,
      spo2: spo2,
      bodyTempC: bodyTemp,
      activeEnergyKcal: activeEnergy,
      baselineRespiratoryRate: median(baseline, 'respiratoryRate'),
      baselineSpo2: median(baseline, 'spo2'),
      baselineBodyTempC: median(baseline, 'bodyTempC'),
      baselineActiveEnergyKcal: baselineEnergy,
    );
  }

  static double _lutealFromFlow(List<HealthSample> samples, DateTime now) {
    final flows = [for (final s in samples) if (s.type == 'menstruationFlow') s.time]
      ..sort();
    if (flows.isEmpty) return 0;
    // Most recent period start = the earliest flow day of the latest contiguous run.
    var start = flows.last;
    for (var i = flows.length - 1; i > 0; i--) {
      if (flows[i].difference(flows[i - 1]).inDays <= 2) {
        start = flows[i - 1];
      } else {
        break;
      }
    }
    final days = now.difference(start).inDays;
    return (days >= 14 && days <= 28) ? 1.0 : 0.0;
  }
}
