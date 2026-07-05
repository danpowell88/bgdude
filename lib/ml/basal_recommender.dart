/// Basal-profile change recommendations.
///
/// The learned [TimeOfDayProfile] measures insulin sensitivity in *carb-free,
/// insulin-active* windows — which, during fasting/overnight stretches, is
/// basal-dominant. A bucket that is *consistently* resistant (multiplier > 1) across
/// many days means basal was too low in that window; consistently sensitive (< 1) means
/// too high. This turns those repeated trends into concrete, conservative per-segment
/// basal-rate suggestions the user can review.
///
/// Like everything in `ml/`, this only ever produces *suggestions*. It never writes to
/// the pump. Changes are surfaced for the user to make on their pump themselves and to
/// discuss with their clinician.
library;

import '../analytics/therapy_settings.dart';
import 'time_of_day_sensitivity.dart';

/// A suggested change to one basal segment.
class BasalSegmentRecommendation {
  const BasalSegmentRecommendation({
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.currentRate,
    required this.suggestedRate,
    required this.avgMultiplier,
    required this.confidence,
    required this.trainedDays,
    required this.rationale,
  });

  /// Segment window (minutes since local midnight). [endMinuteOfDay] may be ≤ start
  /// when the segment wraps past midnight; treat it modulo 1440.
  final int startMinuteOfDay;
  final int endMinuteOfDay;

  final double currentRate; // U/hr
  final double suggestedRate; // U/hr

  /// Observed resistance multiplier over the segment (>1 resistant, <1 sensitive).
  final double avgMultiplier;

  /// 0..1 confidence, from the profile's per-bucket agreement/coverage.
  final double confidence;
  final int trainedDays;
  final String rationale;

  double get changeUnitsPerHour => suggestedRate - currentRate;
  double get changeFraction =>
      currentRate == 0 ? 0 : changeUnitsPerHour / currentRate;
  bool get isIncrease => suggestedRate > currentRate;
}

class BasalRecommendation {
  const BasalRecommendation({
    required this.segments,
    required this.trainedDays,
    required this.generatedAt,
  });

  /// Only segments with a meaningful, confident suggestion (empty when none).
  final List<BasalSegmentRecommendation> segments;
  final int trainedDays;
  final DateTime generatedAt;

  bool get hasSuggestions => segments.isNotEmpty;

  static BasalRecommendation none(DateTime at) =>
      BasalRecommendation(segments: const [], trainedDays: 0, generatedAt: at);
}

class BasalRecommender {
  const BasalRecommender({
    this.minConfidence = 0.45,
    this.minChangeFraction = 0.10,
    this.maxChangeFraction = 0.30,
    this.roundToUnitsPerHour = 0.05,
    this.minTrainedDays = 14,
    this.sampleStepMinutes = 15,
  });

  /// A segment's averaged confidence must clear this to be suggested.
  final double minConfidence;

  /// Ignore suggestions smaller than this fraction of the current rate (noise).
  final double minChangeFraction;

  /// Never suggest a single change larger than this fraction (safety clamp).
  final double maxChangeFraction;

  /// Pump basal granularity to round to (t:slim X2 = 0.05 U/hr for < 15 U/hr, but
  /// 0.05 rounding is a safe display default).
  final double roundToUnitsPerHour;

  /// Below this many trained days the whole profile is untrusted → no suggestions.
  final int minTrainedDays;

  final int sampleStepMinutes;

  BasalRecommendation recommend({
    required TimeOfDayProfile profile,
    required TherapySettings settings,
    required DateTime now,
  }) {
    if (profile.isNeutral || profile.trainedDays < minTrainedDays) {
      return BasalRecommendation.none(now);
    }

    final segs = [...settings.segments]
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    if (segs.isEmpty) return BasalRecommendation.none(now);

    final out = <BasalSegmentRecommendation>[];
    final midnight = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final start = seg.startMinuteOfDay;
      final end = i + 1 < segs.length ? segs[i + 1].startMinuteOfDay : 1440;
      final span = end - start;
      if (span <= 0) continue;

      // Confidence-weighted average multiplier + mean confidence across the segment.
      var weighted = 0.0;
      var weight = 0.0;
      var confSum = 0.0;
      var n = 0;
      for (var m = start; m < end; m += sampleStepMinutes) {
        final t = midnight.add(Duration(minutes: m));
        final mult = profile.multiplierAt(t);
        final conf = profile.confidenceAt(t);
        weighted += mult * conf;
        weight += conf;
        confSum += conf;
        n++;
      }
      if (n == 0 || weight <= 0) continue;
      final avgMult = weighted / weight;
      final avgConf = confSum / n;
      if (avgConf < minConfidence) continue;

      final current = seg.basalUnitsPerHour;
      if (current <= 0) continue;

      // Target = current × observed resistance, capped to a safe single-step change.
      final maxDelta = current * maxChangeFraction;
      final rawDelta = (current * avgMult) - current;
      final delta = rawDelta.clamp(-maxDelta, maxDelta);
      final suggested = _round(current + delta);

      final changeFrac = (suggested - current) / current;
      if (changeFrac.abs() < minChangeFraction) continue;
      if (suggested == current) continue;

      out.add(BasalSegmentRecommendation(
        startMinuteOfDay: start,
        endMinuteOfDay: end % 1440,
        currentRate: current,
        suggestedRate: suggested,
        avgMultiplier: avgMult,
        confidence: avgConf,
        trainedDays: profile.trainedDays,
        rationale: _rationale(start, end, avgMult, profile.trainedDays, changeFrac),
      ));
    }

    return BasalRecommendation(
      segments: out,
      trainedDays: profile.trainedDays,
      generatedAt: now,
    );
  }

  double _round(double v) =>
      (v / roundToUnitsPerHour).round() * roundToUnitsPerHour;

  static String _rationale(
      int start, int end, double mult, int days, double changeFrac) {
    final window = '${_hhmm(start)}–${_hhmm(end % 1440)}';
    final phase = _phase(start);
    final pct = (changeFrac.abs() * 100).round();
    if (mult > 1) {
      return '$window ($phase) ran consistently resistant across $days days — '
          'basal looks about $pct% low here. Consider raising it.';
    }
    return '$window ($phase) ran consistently sensitive across $days days — '
        'basal looks about $pct% high here. Consider lowering it.';
  }

  static String _hhmm(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String _phase(int startMinute) {
    final h = (startMinute ~/ 60) % 24;
    if (h < 3) return 'overnight';
    if (h < 9) return 'dawn/morning';
    if (h < 12) return 'late morning';
    if (h < 15) return 'early afternoon';
    if (h < 18) return 'afternoon';
    if (h < 22) return 'evening';
    return 'overnight';
  }
}
