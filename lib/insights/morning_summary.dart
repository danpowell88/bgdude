/// Morning summary generator. Turns overnight glucose + context (sleep, HRV, prior-day
/// exercise, sensitivity model) into a short, prescriptive daily briefing.
///
/// Each insight is evidence-grounded (see plan research notes) and, because this is a
/// personal tool, allowed to be actionable ("consider bolusing a touch stronger") rather
/// than merely informational. Insights are only emitted when their driver is actually
/// present in the data — no filler.
library;

import '../analytics/metrics.dart';
import '../core/units.dart';
import '../ml/sensitivity_model.dart';

enum InsightSeverity { info, notable, caution }

class Insight {
  const Insight({
    required this.title,
    required this.detail,
    required this.severity,
  });
  final String title;
  final String detail;
  final InsightSeverity severity;
}

class MorningSummary {
  const MorningSummary({
    required this.date,
    required this.headline,
    required this.overnightMetrics,
    required this.insights,
    required this.sensitivity,
  });

  final DateTime date;
  final String headline;
  final GlucoseMetrics overnightMetrics;
  final List<Insight> insights;
  final SensitivityContext sensitivity;
}

class MorningSummaryGenerator {
  const MorningSummaryGenerator({this.unit = GlucoseUnit.mmol});

  final GlucoseUnit unit;

  MorningSummary generate({
    required DateTime date,
    required GlucoseMetrics overnightMetrics,
    required ContextFeatures context,
    required SensitivityContext sensitivity,
    bool alcoholYesterday = false,
    bool intenseExerciseYesterday = false,
  }) {
    final insights = <Insight>[];

    // Overnight glycaemia.
    if (overnightMetrics.timeBelow70 > 0.04) {
      insights.add(Insight(
        title: 'Overnight lows',
        detail:
            'You spent ${(overnightMetrics.timeBelow70 * 100).round()}% of the night below range. '
            'Check the timeline for a pattern (basal, late bolus, or a compression low).',
        severity: InsightSeverity.caution,
      ));
    } else if (overnightMetrics.timeInRange > 0.85) {
      insights.add(const Insight(
        title: 'Steady night',
        detail: 'Mostly in range overnight — a good baseline to start the day.',
        severity: InsightSeverity.info,
      ));
    }

    // Sleep-driven sensitivity.
    if (context.sleepHours < 6) {
      insights.add(Insight(
        title: 'Short sleep',
        detail:
            'Only ${context.sleepHours.toStringAsFixed(1)}h of sleep. Short sleep typically '
            'reduces insulin sensitivity by ~15–25%. Consider slightly stronger boluses and '
            'earlier pre-bolusing today.',
        severity: InsightSeverity.notable,
      ));
    }

    // HRV / autonomic load.
    if (context.baselineHrv > 0 &&
        context.overnightHrvRmssd < context.baselineHrv * 0.85) {
      insights.add(const Insight(
        title: 'HRV below baseline',
        detail:
            'Overnight HRV is down on your baseline, which tends to track with more insulin '
            'resistance. Watch for stubborn highs and correct a little sooner.',
        severity: InsightSeverity.notable,
      ));
    }

    // Post-exercise heightened sensitivity / nocturnal risk.
    if (intenseExerciseYesterday) {
      insights.add(const Insight(
        title: 'Post-exercise sensitivity',
        detail:
            'Yesterday\'s hard session can keep you more insulin-sensitive for up to 24–48h, '
            'raising delayed and overnight hypo risk. Consider easing corrections today.',
        severity: InsightSeverity.caution,
      ));
    }

    // Menstrual phase.
    if (context.menstrualLutealPhase > 0.5) {
      insights.add(const Insight(
        title: 'Luteal phase',
        detail:
            'Luteal-phase progesterone often raises insulin resistance. If you see it in your '
            'numbers, a modest basal/bolus bump can help.',
        severity: InsightSeverity.notable,
      ));
    }

    // Illness.
    if (context.illnessFlag > 0.5) {
      insights.add(const Insight(
        title: 'Illness flagged',
        detail:
            'Illness raises glucose and insulin needs. Expect higher readings and check '
            'ketones if you run high with normal IOB.',
        severity: InsightSeverity.caution,
      ));
    }

    // Alcohol from yesterday → delayed lows.
    if (alcoholYesterday) {
      insights.add(const Insight(
        title: 'Alcohol yesterday',
        detail:
            'Alcohol can cause delayed lows for many hours. Be conservative with corrections '
            'and keep fast carbs handy.',
        severity: InsightSeverity.caution,
      ));
    }

    final headline = _headline(sensitivity, overnightMetrics);

    return MorningSummary(
      date: date,
      headline: headline,
      overnightMetrics: overnightMetrics,
      insights: insights,
      sensitivity: sensitivity,
    );
  }

  String _headline(SensitivityContext s, GlucoseMetrics m) {
    final mult = s.effectiveMultiplier;
    if (s.confidence > 0.3 && mult >= 1.1) {
      final pct = ((mult - 1) * 100).round();
      return 'Likely ~$pct% more insulin-resistant today (${s.reasons.join(', ')}).';
    }
    if (s.confidence > 0.3 && mult <= 0.9) {
      final pct = ((1 - mult) * 100).round();
      return 'Likely ~$pct% more insulin-sensitive today — watch for lows.';
    }
    if (m.timeInRange > 0.85) return 'Solid overnight — steady start.';
    return 'No strong sensitivity signal today; run your usual settings.';
  }
}
