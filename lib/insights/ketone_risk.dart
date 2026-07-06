/// Sick-day / DKA safety: when glucose has been high for a while *and* something is
/// pushing toward ketosis — illness, a likely site failure (insulin not working), or being
/// very high with almost no insulin on board (a missed dose or occlusion) — prompt a
/// ketone check. This is a rules-based heads-up (the pump/CGM don't measure ketones);
/// it plugs into continuous ketone sensors later if that data becomes available.
///
/// A plain high with insulin working is NOT flagged — that's just a correction in progress.
library;

import '../core/samples.dart';

class KetoneRiskResult {
  const KetoneRiskResult({required this.suggestCheck, this.reason = ''});
  final bool suggestCheck;
  final String reason;
  static const none = KetoneRiskResult(suggestCheck: false);
}

class KetoneRiskDetector {
  const KetoneRiskDetector({
    this.highThresholdMgdl = 250, // ~13.9 mmol/L (P0-7: lowered from 270)
    this.veryHighThresholdMgdl = 300, // ~16.7 mmol/L
    this.sustainMinutes = 120,
    this.minReadings = 6,
    this.highFraction = 0.8,
    this.lowIobUnits = 0.3,
  });

  final double highThresholdMgdl;

  /// Above this, a rising glucose or very-low IOB prompts a ketone check
  /// **unconditionally** (no illness/site factor required) — a rising very-high can
  /// precede DKA (P0-7).
  final double veryHighThresholdMgdl;
  final int sustainMinutes;
  final int minReadings;

  /// Fraction of the recent window that must be above threshold to count as sustained.
  final double highFraction;

  /// Below this IOB, being very high suggests missed insulin / occlusion.
  final double lowIobUnits;

  KetoneRiskResult detect({
    required List<CgmSample> cgm,
    required double iobUnits,
    required bool illnessActive,
    bool likelySiteIssue = false,
    required DateTime now,
  }) {
    final from = now.subtract(Duration(minutes: sustainMinutes));
    final recent = [
      for (final s in cgm)
        if (!s.sensorWarmup &&
            s.mgdl > 0 &&
            !s.time.isBefore(from) &&
            !s.time.isAfter(now))
          s,
    ]..sort((a, b) => a.time.compareTo(b.time));
    if (recent.length < minReadings) return KetoneRiskResult.none;

    final above =
        recent.where((s) => s.mgdl > highThresholdMgdl).length / recent.length;
    final stillHigh = recent.last.mgdl > highThresholdMgdl;
    if (above < highFraction || !stillHigh) return KetoneRiskResult.none;

    // P0-7: unconditional prompt when very high AND (still rising OR little insulin on
    // board) — a rising very-high can precede DKA even without a named risk factor.
    final veryHigh = recent.last.mgdl > veryHighThresholdMgdl;
    final rising = recent.length >= 2 && recent.last.mgdl > recent.first.mgdl;
    if (veryHigh && (rising || iobUnits < lowIobUnits)) {
      return KetoneRiskResult(
        suggestCheck: true,
        reason: rising
            ? 'Very high and still rising — check ketones now and correct; a rising '
                'very-high can precede DKA.'
            : 'Very high with almost no insulin on board — check ketones now and '
                'correct (a missed dose or occlusion can cause ketones).',
      );
    }

    // A ketone-promoting factor must accompany the sustained high.
    if (illnessActive) {
      return const KetoneRiskResult(
        suggestCheck: true,
        reason: 'You’ve been high while unwell — illness raises DKA risk. Check '
            'ketones and follow your sick-day plan (hydrate, correct, recheck).',
      );
    }
    if (likelySiteIssue) {
      return const KetoneRiskResult(
        suggestCheck: true,
        reason: 'High for hours with insulin doing little — a site failure can let '
            'ketones build. Check ketones and consider a set change.',
      );
    }
    if (iobUnits < lowIobUnits) {
      return const KetoneRiskResult(
        suggestCheck: true,
        reason: 'Very high with almost no insulin on board — a missed dose or '
            'occlusion can cause ketones. Check ketones and correct.',
      );
    }
    return KetoneRiskResult.none;
  }
}
