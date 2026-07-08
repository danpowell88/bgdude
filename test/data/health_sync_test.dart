import 'package:bgdude/data/health_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

/// HealthSyncService.fetch() has real per-type transformation and sleep-
/// aggregation logic (16 numeric mappings, nutrition-carb extraction, workout activity
/// naming, sleep-stage minute accumulation, pre-noon night-key grouping) that was
/// entirely uncovered -- fetch() only ever runs against the real Health Connect plugin
/// on-device. Health's methods aren't final, so a fake subclass overriding just the two
/// plugin-touching methods (getHealthDataFromTypes, removeDuplicates) exercises every
/// other line of fetch() headlessly, with real HealthDataPoint/HealthValue objects (all
/// plain public constructors from the health package).
class _FixtureHealth extends Health {
  _FixtureHealth(this._points);
  final List<HealthDataPoint> _points;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async =>
      _points;

  @override
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) =>
      points;
}

HealthDataPoint _numeric(HealthDataType type, num value, DateTime at,
        {HealthDataUnit unit = HealthDataUnit.NO_UNIT}) =>
    HealthDataPoint(
      uuid: '$type-${at.millisecondsSinceEpoch}',
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: unit,
      dateFrom: at,
      dateTo: at,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'test',
      sourceId: 'test',
      sourceName: 'test-source',
    );

Future<List<HealthSample>> _fetch(List<HealthDataPoint> points) =>
    HealthSyncService(health: _FixtureHealth(points))
        .fetch(DateTime(2026, 7, 1), DateTime(2026, 7, 2));

void main() {
  group('HealthSyncService.fetch numeric mappings', () {
    final at = DateTime(2026, 7, 1, 8);

    final cases = <HealthDataType, HealthMetric>{
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD: HealthMetric.hrvRmssd,
      HealthDataType.RESTING_HEART_RATE: HealthMetric.restingHr,
      HealthDataType.HEART_RATE: HealthMetric.heartRate,
      HealthDataType.STEPS: HealthMetric.steps,
      HealthDataType.DISTANCE_DELTA: HealthMetric.distanceM,
      HealthDataType.FLIGHTS_CLIMBED: HealthMetric.flights,
      HealthDataType.ACTIVE_ENERGY_BURNED: HealthMetric.activeEnergyKcal,
      HealthDataType.TOTAL_CALORIES_BURNED: HealthMetric.totalEnergyKcal,
      HealthDataType.BLOOD_OXYGEN: HealthMetric.spo2,
      HealthDataType.RESPIRATORY_RATE: HealthMetric.respiratoryRate,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC: HealthMetric.bpSystolic,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC: HealthMetric.bpDiastolic,
      HealthDataType.BODY_TEMPERATURE: HealthMetric.bodyTempC,
      HealthDataType.WEIGHT: HealthMetric.weightKg,
      HealthDataType.BODY_FAT_PERCENTAGE: HealthMetric.bodyFatPct,
      HealthDataType.WATER: HealthMetric.waterL,
      HealthDataType.MENSTRUATION_FLOW: HealthMetric.menstruationFlow,
    };

    for (final entry in cases.entries) {
      test('${entry.key.name} -> ${entry.value.name}', () async {
        final samples = await _fetch([_numeric(entry.key, 42, at)]);
        expect(samples, hasLength(1));
        expect(samples.single.type, entry.value);
        expect(samples.single.value, 42);
        expect(samples.single.time, at);
      });
    }

    test('an unrecognised type is silently ignored', () async {
      final samples =
          await _fetch([_numeric(HealthDataType.MINDFULNESS, 5, at)]);
      expect(samples, isEmpty);
    });
  });

  group('HealthSyncService.fetch nutrition', () {
    test('a nutrition point with carbs becomes a dietaryCarbsG sample', () async {
      final at = DateTime(2026, 7, 1, 12);
      final point = HealthDataPoint(
        uuid: 'n1',
        value: NutritionHealthValue(carbs: 55.5),
        type: HealthDataType.NUTRITION,
        unit: HealthDataUnit.GRAM,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test',
        sourceId: 'test',
        sourceName: 'test-source',
      );

      final samples = await _fetch([point]);

      expect(samples, hasLength(1));
      expect(samples.single.type, HealthMetric.dietaryCarbsG);
      expect(samples.single.value, 55.5);
    });

    test('a nutrition point with no carbs field yields no sample', () async {
      final at = DateTime(2026, 7, 1, 12);
      final point = HealthDataPoint(
        uuid: 'n2',
        value: NutritionHealthValue(),
        type: HealthDataType.NUTRITION,
        unit: HealthDataUnit.GRAM,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test',
        sourceId: 'test',
        sourceName: 'test-source',
      );

      expect(await _fetch([point]), isEmpty);
    });
  });

  group('HealthSyncService.fetch workouts', () {
    test('a workout becomes an exercise sample with duration and activity meta',
        () async {
      final start = DateTime(2026, 7, 1, 7);
      final end = start.add(const Duration(minutes: 45));
      final point = HealthDataPoint(
        uuid: 'w1',
        value:
            WorkoutHealthValue(workoutActivityType: HealthWorkoutActivityType.RUNNING),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.MINUTE,
        dateFrom: start,
        dateTo: end,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test',
        sourceId: 'test',
        sourceName: 'Garmin Connect',
      );

      final samples = await _fetch([point]);

      expect(samples, hasLength(1));
      final s = samples.single;
      expect(s.type, HealthMetric.exercise);
      expect(s.value, 45); // minutes
      expect(s.workout.activity, 'RUNNING');
      expect(s.workout.source, 'Garmin Connect');
    });

    test('a workout with a non-WorkoutHealthValue falls back to the source name',
        () async {
      final start = DateTime(2026, 7, 1, 7);
      final point = HealthDataPoint(
        uuid: 'w2',
        value: NumericHealthValue(numericValue: 30),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.MINUTE,
        dateFrom: start,
        dateTo: start.add(const Duration(minutes: 30)),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test',
        sourceId: 'test',
        sourceName: 'Some Other App',
      );

      final samples = await _fetch([point]);

      expect(samples.single.workout.activity, 'Some Other App');
    });
  });

  group('HealthSyncService.fetch sleep aggregation', () {
    HealthDataPoint sleepStage(
      HealthDataType type,
      DateTime from,
      DateTime to,
    ) =>
        HealthDataPoint(
          uuid: '$type-${from.millisecondsSinceEpoch}',
          value: NumericHealthValue(numericValue: to.difference(from).inMinutes),
          type: type,
          unit: HealthDataUnit.MINUTE,
          dateFrom: from,
          dateTo: to,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'test',
          sourceId: 'test',
          sourceName: 'test-source',
        );

    test('asleep/deep/awake stages aggregate into hours + efficiency for one night',
        () async {
      // 23:00 -> 06:00 asleep (7h), of which 23:00->01:00 is deep (2h); 06:00->06:30
      // awake-in-bed (0.5h). Night key groups the whole span under the 23:00 date
      // (pre-noon rollover applies only to points that start after midnight).
      final night = DateTime(2026, 7, 1);
      final points = [
        sleepStage(HealthDataType.SLEEP_DEEP, DateTime(2026, 7, 1, 23),
            DateTime(2026, 7, 2, 1)),
        sleepStage(HealthDataType.SLEEP_ASLEEP, DateTime(2026, 7, 2, 1),
            DateTime(2026, 7, 2, 6)),
        sleepStage(HealthDataType.SLEEP_AWAKE, DateTime(2026, 7, 2, 6),
            DateTime(2026, 7, 2, 6, 30)),
      ];

      final samples = await _fetch(points);
      final byType = {for (final s in samples) s.type: s};

      // The two post-midnight points (01:00, 06:00) roll back to the 07-01 night key
      // (hour < 12); the 23:00 point is already on 07-01.
      expect(byType[HealthMetric.sleepHours]!.time, night);
      expect(byType[HealthMetric.sleepHours]!.value, closeTo(7.0, 1e-9));
      expect(byType[HealthMetric.sleepDeepHours]!.value, closeTo(2.0, 1e-9));
      // Efficiency = asleep / (asleep + awake) = 7 / 7.5.
      expect(byType[HealthMetric.sleepEfficiency]!.value, closeTo(7 / 7.5, 1e-9));
    });

    test('a night with zero total minutes has zero efficiency, not NaN', () async {
      // A zero-duration awake point touches the night's accumulator (creating an
      // entry via putIfAbsent) without contributing any asleep or awake minutes --
      // total stays 0, exercising the total==0 branch instead of a divide-by-zero.
      final points = [
        sleepStage(HealthDataType.SLEEP_AWAKE, DateTime(2026, 7, 1, 3),
            DateTime(2026, 7, 1, 3)),
      ];

      final samples = await _fetch(points);
      final eff =
          samples.singleWhere((s) => s.type == HealthMetric.sleepEfficiency);
      expect(eff.value, 0);
    });

    test('a pre-noon sleep point stays on its own calendar day (no rollback)',
        () async {
      // hour < 12 rolls back a day -- a point actually AT/after noon must not.
      final points = [
        sleepStage(HealthDataType.SLEEP_ASLEEP, DateTime(2026, 7, 1, 14),
            DateTime(2026, 7, 1, 15)),
      ];

      final samples = await _fetch(points);
      final hours =
          samples.singleWhere((s) => s.type == HealthMetric.sleepHours);
      expect(hours.time, DateTime(2026, 7, 1));
    });
  });

  group('HealthMetric.fromDbString', () {
    test('round-trips every enum value through its persisted db string', () {
      for (final m in HealthMetric.values) {
        expect(HealthMetric.fromDbString(m.dbString), m);
      }
    });

    test('an unknown persisted string returns null rather than throwing', () {
      expect(HealthMetric.fromDbString('some_future_metric'), isNull);
    });
  });
}
