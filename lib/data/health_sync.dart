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

/// A normalised contextual sample ready to persist to `health_samples`.
class HealthSample {
  const HealthSample({
    required this.time,
    required this.type,
    required this.value,
    this.meta = const {},
  });

  final DateTime time;

  /// 'sleepHours' | 'sleepEfficiency' | 'hrvRmssd' | 'restingHr' | 'steps' | 'exercise'
  final String type;
  final double value;
  final Map<String, Object?> meta;
}

class HealthSyncService {
  HealthSyncService({Health? health}) : _health = health ?? Health();

  final Health _health;
  final _log = Logger('HealthSync');

  static const _readTypes = <HealthDataType>[
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
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
              type: 'hrvRmssd',
              value: _numeric(point)));
        case HealthDataType.RESTING_HEART_RATE:
          out.add(HealthSample(
              time: point.dateFrom,
              type: 'restingHr',
              value: _numeric(point)));
        case HealthDataType.STEPS:
          out.add(HealthSample(
              time: point.dateFrom, type: 'steps', value: _numeric(point)));
        case HealthDataType.WORKOUT:
          out.add(HealthSample(
            time: point.dateFrom,
            type: 'exercise',
            value: point.dateTo.difference(point.dateFrom).inMinutes.toDouble(),
            meta: {'activity': point.sourceName},
          ));
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_DEEP:
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_REM:
          final night = _nightKey(point.dateFrom);
          final acc = sleepByNight.putIfAbsent(night, _SleepAcc.new);
          acc.asleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
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
            time: night, type: 'sleepHours', value: acc.asleepMinutes / 60.0))
        ..add(HealthSample(
            time: night,
            type: 'sleepEfficiency',
            value: total == 0 ? 0 : acc.asleepMinutes / total));
    });

    return out;
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
}
