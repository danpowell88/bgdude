/// Health Connect ingestion. Pulls the contextual signals the sensitivity/insight models
/// need — sleep stages, HRV (RMSSD), resting HR, steps, exercise sessions — via the
/// `health` package, which wraps Android Health Connect.
///
/// The user's Garmin data reaches Health Connect through Garmin Connect → Google
/// Health/Fit sync, so from this app's perspective everything is just Health Connect
/// records. Google Fit's own APIs are being retired (end of 2026); Health Connect is the
/// forward-compatible source.
library;

import 'package:health/health.dart';
import 'package:logging/logging.dart';

/// Every contextual metric the app ingests (TASK-118). The [dbString] values are
/// the exact strings already persisted in `health_samples.type` — adding here is
/// fine, renaming is a DB migration.
enum HealthMetric {
  sleepHours('sleepHours'),
  sleepDeepHours('sleepDeepHours'),
  sleepEfficiency('sleepEfficiency'),
  hrvRmssd('hrvRmssd'),
  restingHr('restingHr'),
  heartRate('heartRate'),
  steps('steps'),
  distanceM('distanceM'),
  flights('flights'),
  activeEnergyKcal('activeEnergyKcal'),
  totalEnergyKcal('totalEnergyKcal'),
  spo2('spo2'),
  respiratoryRate('respiratoryRate'),
  bpSystolic('bpSystolic'),
  bpDiastolic('bpDiastolic'),
  bodyTempC('bodyTempC'),
  weightKg('weightKg'),
  bodyFatPct('bodyFatPct'),
  waterL('waterL'),
  dietaryCarbsG('dietaryCarbsG'),
  menstruationFlow('menstruationFlow'),
  exercise('exercise');

  const HealthMetric(this.dbString);

  /// The persisted string — identical to the pre-enum values (no migration).
  final String dbString;

  static final Map<String, HealthMetric> _byDb = {
    for (final m in HealthMetric.values) m.dbString: m,
  };

  /// Null for a string this build doesn't know (e.g. a newer schema) — the
  /// repository skips such rows rather than guessing.
  static HealthMetric? fromDbString(String s) => _byDb[s];
}

/// Typed view of a workout sample's [HealthSample.meta] (TASK-118).
class WorkoutMeta {
  const WorkoutMeta({this.activity = '', this.source = ''});

  /// Health Connect activity type name (RUNNING, STRENGTH_TRAINING, ...).
  final String activity;
  final String source;

  Map<String, Object?> toMeta() => {'activity': activity, 'source': source};

  factory WorkoutMeta.fromMeta(Map<String, Object?> meta) => WorkoutMeta(
        activity: meta['activity'] as String? ?? '',
        source: meta['source'] as String? ?? '',
      );
}

/// A normalised contextual sample ready to persist to `health_samples`.
class HealthSample {
  const HealthSample({
    required this.time,
    required this.type,
    required this.value,
    this.meta = const {},
  });

  final DateTime time;
  final HealthMetric type;
  final double value;
  final Map<String, Object?> meta;

  /// Typed workout metadata (meaningful when [type] is [HealthMetric.exercise]).
  WorkoutMeta get workout => WorkoutMeta.fromMeta(meta);
}

class HealthSyncService {
  HealthSyncService({Health? health}) : _health = health ?? Health();

  final Health _health;
  final _log = Logger('HealthSync');

  /// The full set of Health Connect types we ingest. Beyond the sleep/HR/activity
  /// signals the models use directly, we pull the broader picture (energy, weight,
  /// SpO2, respiratory rate, blood pressure, temperature, hydration, nutrition,
  /// menstruation) so insights can correlate against it and future models can use it.
  static const _readTypes = <HealthDataType>[
    // Sleep stages
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    // Cardio / autonomic
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    // Activity / energy
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WORKOUT,
    // Body
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    // Nutrition / hydration
    HealthDataType.WATER,
    HealthDataType.NUTRITION,
    // Reproductive
    HealthDataType.MENSTRUATION_FLOW,
    // Glucose (also written back)
    HealthDataType.BLOOD_GLUCOSE,
  ];

  /// Request the read permissions (and history/background access). Call during onboarding.
  Future<bool> requestPermissions() async {
    await _health.configure();
    final granted = await _health.requestAuthorization(
      _readTypes,
      permissions: List.filled(_readTypes.length, HealthDataAccess.READ),
    );
    // Broaden beyond the default 30-day window and allow background reads where available.
    try {
      await _health.requestHealthDataHistoryAuthorization();
      if (await _health.isHealthDataInBackgroundAvailable()) {
        await _health.requestHealthDataInBackgroundAuthorization();
      }
    } catch (e) {
      _log.info('history/background auth not available: $e');
    }
    return granted;
  }

  /// Fetch and normalise contextual samples in [from, to).
  Future<List<HealthSample>> fetch(DateTime from, DateTime to) async {
    final raw = await _health.getHealthDataFromTypes(
      types: _readTypes,
      startTime: from,
      endTime: to,
    );
    final deduped = _health.removeDuplicates(raw);

    final out = <HealthSample>[];
    // Aggregate sleep into per-night hours + efficiency.
    final sleepByNight = <DateTime, _SleepAcc>{};

    for (final point in deduped) {
      switch (point.type) {
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          out.add(HealthSample(
              time: point.dateFrom,
              type: HealthMetric.hrvRmssd,
              value: _numeric(point)));
        case HealthDataType.RESTING_HEART_RATE:
          out.add(HealthSample(
              time: point.dateFrom,
              type: HealthMetric.restingHr,
              value: _numeric(point)));
        case HealthDataType.HEART_RATE:
          // Per-reading heart rate — an acute exercise/stress signal for the forecaster.
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.heartRate, value: _numeric(point)));
        case HealthDataType.STEPS:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.steps, value: _numeric(point)));
        case HealthDataType.DISTANCE_DELTA:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.distanceM, value: _numeric(point)));
        case HealthDataType.FLIGHTS_CLIMBED:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.flights, value: _numeric(point)));
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.activeEnergyKcal, value: _numeric(point)));
        case HealthDataType.TOTAL_CALORIES_BURNED:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.totalEnergyKcal, value: _numeric(point)));
        case HealthDataType.BLOOD_OXYGEN:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.spo2, value: _numeric(point)));
        case HealthDataType.RESPIRATORY_RATE:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.respiratoryRate, value: _numeric(point)));
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.bpSystolic, value: _numeric(point)));
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.bpDiastolic, value: _numeric(point)));
        case HealthDataType.BODY_TEMPERATURE:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.bodyTempC, value: _numeric(point)));
        case HealthDataType.WEIGHT:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.weightKg, value: _numeric(point)));
        case HealthDataType.BODY_FAT_PERCENTAGE:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.bodyFatPct, value: _numeric(point)));
        case HealthDataType.WATER:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.waterL, value: _numeric(point)));
        case HealthDataType.NUTRITION:
          // Store dietary carbs (informational — not auto-logged as a bolus carb entry
          // to avoid double-counting the pump's own carbs).
          final carbs = _nutritionCarbs(point);
          if (carbs != null) {
            out.add(HealthSample(
                time: point.dateFrom, type: HealthMetric.dietaryCarbsG, value: carbs));
          }
        case HealthDataType.MENSTRUATION_FLOW:
          out.add(HealthSample(
              time: point.dateFrom, type: HealthMetric.menstruationFlow, value: _numeric(point)));
        case HealthDataType.WORKOUT:
          final v = point.value;
          out.add(HealthSample(
            time: point.dateFrom,
            type: HealthMetric.exercise,
            value: point.dateTo.difference(point.dateFrom).inMinutes.toDouble(),
            // Capture the workout activity type (RUNNING, STRENGTH_TRAINING, …) so the
            // aerobic-vs-resistance classifier can tailor post-exercise hypo risk.
            meta: WorkoutMeta(
              activity: v is WorkoutHealthValue
                  ? v.workoutActivityType.name
                  : point.sourceName,
              source: point.sourceName,
            ).toMeta(),
          ));
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_REM:
          final night = _nightKey(point.dateFrom);
          final acc = sleepByNight.putIfAbsent(night, _SleepAcc.new);
          acc.asleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
        case HealthDataType.SLEEP_DEEP:
          final night = _nightKey(point.dateFrom);
          final acc = sleepByNight.putIfAbsent(night, _SleepAcc.new);
          final mins = point.dateTo.difference(point.dateFrom).inMinutes;
          acc.asleepMinutes += mins;
          acc.deepMinutes += mins;
        case HealthDataType.SLEEP_AWAKE:
          final night = _nightKey(point.dateFrom);
          final acc = sleepByNight.putIfAbsent(night, _SleepAcc.new);
          acc.awakeMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
        default:
          break;
      }
    }

    sleepByNight.forEach((night, acc) {
      final total = acc.asleepMinutes + acc.awakeMinutes;
      out
        ..add(HealthSample(
            time: night, type: HealthMetric.sleepHours, value: acc.asleepMinutes / 60.0))
        ..add(HealthSample(
            time: night, type: HealthMetric.sleepDeepHours, value: acc.deepMinutes / 60.0))
        ..add(HealthSample(
            time: night,
            type: HealthMetric.sleepEfficiency,
            value: total == 0 ? 0 : acc.asleepMinutes / total));
    });

    return out;
  }

  static double? _nutritionCarbs(HealthDataPoint p) {
    final v = p.value;
    if (v is NutritionHealthValue) return v.carbs?.toDouble();
    return null;
  }

  static double _numeric(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return 0;
  }

  /// Group pre-noon sleep with the previous calendar day (a "night").
  static DateTime _nightKey(DateTime t) {
    final d = t.hour < 12 ? t.subtract(const Duration(days: 1)) : t;
    return DateTime(d.year, d.month, d.day);
  }
}

class _SleepAcc {
  int asleepMinutes = 0;
  int awakeMinutes = 0;
  int deepMinutes = 0;
}
