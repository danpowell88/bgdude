/// Core immutable time-series sample types shared across the analytics, ML, and
/// storage layers. These are plain value types (no drift/db coupling) so the pure
/// engines can be unit tested without a database.
library;

import 'units.dart';

/// CGM trend arrow, as reported by the pump's connected Dexcom.
enum GlucoseTrend {
  doubleUp,
  singleUp,
  fortyFiveUp,
  flat,
  fortyFiveDown,
  singleDown,
  doubleDown,
  unknown;

  /// Approximate rate of change in mg/dL per minute, used when the raw
  /// delta is unavailable. Dexcom arrow buckets map to these midpoints.
  double get mgdlPerMin => switch (this) {
        GlucoseTrend.doubleUp => 3.5,
        GlucoseTrend.singleUp => 2.0,
        GlucoseTrend.fortyFiveUp => 1.0,
        GlucoseTrend.flat => 0.0,
        GlucoseTrend.fortyFiveDown => -1.0,
        GlucoseTrend.singleDown => -2.0,
        GlucoseTrend.doubleDown => -3.5,
        GlucoseTrend.unknown => 0.0,
      };
}

/// A single CGM reading.
class CgmSample {
  const CgmSample({
    required this.time,
    required this.mgdl,
    this.trend = GlucoseTrend.unknown,
    this.isCalibration = false,
    this.sensorWarmup = false,
    this.compressionLow = false,
  });

  final DateTime time;
  final double mgdl;
  final GlucoseTrend trend;
  final bool isCalibration;

  /// True while the sensor is in warm-up (readings unreliable / absent).
  final bool sensorWarmup;

  /// Flagged as a compression-low artefact (nocturnal sensor pressure), so analytics
  /// and training can exclude it. Set by the detector or a known-simulated event.
  final bool compressionLow;

  Mgdl get glucose => Mgdl(mgdl);
}

/// A bolus delivery record (from pump history / last-bolus status).
class BolusEvent {
  const BolusEvent({
    required this.time,
    required this.units,
    this.carbsGrams = 0,
    this.isExtended = false,
    this.durationMinutes = 0,
    this.isAutomatic = false,
  });

  final DateTime time;

  /// Insulin units delivered (or programmed, for still-running extended boluses).
  final double units;

  /// Carbs entered on the pump for this bolus, if any.
  final double carbsGrams;

  final bool isExtended;
  final int durationMinutes;

  /// True for Control-IQ automatic correction boluses.
  final bool isAutomatic;
}

/// A segment of basal delivery at a constant rate. Temp basals and Control-IQ
/// adjustments produce additional segments layered over the profile.
class BasalSegment {
  const BasalSegment({
    required this.start,
    required this.end,
    required this.unitsPerHour,
  });

  final DateTime start;
  final DateTime end;
  final double unitsPerHour;

  Duration get duration => end.difference(start);
  double get totalUnits => unitsPerHour * duration.inMinutes / 60.0;
}

/// A carbohydrate entry (from pump bolus wizard or user-logged in-app).
class CarbEntry {
  const CarbEntry({
    required this.time,
    required this.grams,
    this.absorptionMinutes = 180,
  });

  final DateTime time;
  final double grams;

  /// Expected absorption duration; the dynamic model may shorten/lengthen this.
  final int absorptionMinutes;
}
