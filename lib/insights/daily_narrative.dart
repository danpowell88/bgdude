/// "Your Day" narrative generator. Turns the current glucose picture (reading +
/// trend), today's metrics so far, the sensitivity context, and a short forecast
/// into a warm, plain-English briefing.
///
/// This is fully deterministic — no LLM. Every clause is gated on a real driver in
/// the input, so the narrative never pads with filler. It mirrors the "insight only
/// when its driver is present" rule used by [MorningSummaryGenerator], but frames the
/// output as one continuous story (headline + body + a few suggestions) rather than a
/// list of cards.
///
/// All glucose values are mg/dL internally and only rendered through
/// `Mgdl(...).display(unit)` at the text boundary.
library;

import '../analytics/metrics.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../core/units.dart';

/// Everything the generator needs to describe "your day". A provider assembles this
/// from the live pump snapshot, today's [GlucoseMetrics], the effective
/// [SensitivityContext], and the forecaster's min/max.
class DailyNarrativeInput {
  const DailyNarrativeInput({
    required this.now,
    required this.currentMgdl,
    required this.trend,
    required this.todayMetrics,
    required this.sensitivity,
    required this.predictedLowMgdl,
    required this.predictedHighMgdl,
    this.notableEventCount = 0,
    this.illnessActive = false,
    this.alcoholYesterday = false,
    this.unit = GlucoseUnit.mmol,
  });

  /// Local wall-clock time the narrative is generated for. Drives time-of-day framing.
  final DateTime now;

  /// Most recent CGM value in mg/dL, or null if there's no live reading.
  final double? currentMgdl;

  /// Current CGM trend arrow.
  final GlucoseTrend trend;

  /// Today-so-far glycaemic metrics (TIR, mean, reading count).
  final GlucoseMetrics todayMetrics;

  /// Context sensitivity adjustment for today (resistant / sensitive drivers).
  final SensitivityContext sensitivity;

  /// Minimum of the near-term forecast in mg/dL, or null if no forecast.
  final double? predictedLowMgdl;

  /// Maximum of the near-term forecast in mg/dL, or null if no forecast.
  final double? predictedHighMgdl;

  /// Count of notable events detected today (used only to colour the body).
  final int notableEventCount;

  /// True when the user has flagged a sick day.
  final bool illnessActive;

  /// True when alcohol was logged yesterday (delayed-low risk).
  final bool alcoholYesterday;

  /// Display unit for all rendered glucose values.
  final GlucoseUnit unit;
}

/// The generated narrative: a short headline, a woven 2–4 sentence body, and 0–3
/// actionable suggestions.
class DailyNarrative {
  const DailyNarrative({
    required this.headline,
    required this.body,
    required this.suggestions,
  });

  final String headline;
  final String body;
  final List<String> suggestions;
}

/// Time-of-day buckets used for framing.
enum _DayPart { morning, afternoon, evening, overnight }

class DailyNarrativeGenerator {
  const DailyNarrativeGenerator();

  /// Below this many readings today, we treat it as "still early" and avoid making
  /// claims about time-in-range (one 5-min-cadence hour ≈ 12 readings).
  static const int _earlyReadingThreshold = 12;

  /// Effective multiplier at/above this is "resistant"; at/below [_sensitiveThreshold]
  /// is "sensitive". These are the same bands the morning summary uses.
  static const double _resistantThreshold = 1.1;
  static const double _sensitiveThreshold = 0.9;

  /// A forecast dipping below this (mg/dL) is worth a heads-up.
  static const double _lowWatchMgdl = 80;

  /// A forecast climbing above this (mg/dL) is worth a heads-up.
  static const double _highWatchMgdl = 200;

  DailyNarrative generate(DailyNarrativeInput input) {
    final unit = input.unit;
    final part = _partOfDay(input.now.hour);
    final mult = input.sensitivity.effectiveMultiplier;
    final resistant = mult >= _resistantThreshold;
    final sensitive = mult <= _sensitiveThreshold;
    final early = input.todayMetrics.readingCount < _earlyReadingThreshold;

    final predictedLow = input.predictedLowMgdl;
    final lowLooming = predictedLow != null && predictedLow < _lowWatchMgdl;
    final predictedHigh = input.predictedHighMgdl;
    final highLooming = predictedHigh != null && predictedHigh > _highWatchMgdl;

    final headline = _headline(
      part: part,
      lowLooming: lowLooming,
      highLooming: highLooming,
      illness: input.illnessActive,
      resistant: resistant,
      sensitive: sensitive,
      early: early,
      metrics: input.todayMetrics,
    );

    final body = _body(
      input: input,
      unit: unit,
      resistant: resistant,
      sensitive: sensitive,
      early: early,
    );

    final suggestions = _suggestions(
      input: input,
      unit: unit,
      resistant: resistant,
      sensitive: sensitive,
      lowLooming: lowLooming,
      highLooming: highLooming,
      predictedLow: predictedLow,
    );

    return DailyNarrative(
      headline: headline,
      body: body,
      suggestions: suggestions,
    );
  }

  _DayPart _partOfDay(int hour) {
    if (hour >= 5 && hour < 12) return _DayPart.morning;
    if (hour >= 12 && hour < 17) return _DayPart.afternoon;
    if (hour >= 17 && hour < 22) return _DayPart.evening;
    return _DayPart.overnight;
  }

  String _greeting(_DayPart part) => switch (part) {
        _DayPart.morning => 'Good morning',
        _DayPart.afternoon => 'Good afternoon',
        _DayPart.evening => 'Good evening',
        _DayPart.overnight => 'Overnight',
      };

  String _headline({
    required _DayPart part,
    required bool lowLooming,
    required bool highLooming,
    required bool illness,
    required bool resistant,
    required bool sensitive,
    required bool early,
    required GlucoseMetrics metrics,
  }) {
    final greeting = _greeting(part);
    final signal = () {
      // Safety first, then durable context signals, then today's shape.
      if (lowLooming) return 'keep an eye out for a low';
      if (illness) return 'taking it gently while you\'re unwell';
      if (resistant) return 'running a bit resistant today';
      if (sensitive) return 'more insulin-sensitive today';
      if (early) return 'still early in the day';
      if (highLooming) return 'a high may be building';
      if (metrics.timeInRange >= 0.70) return 'a steady day so far';
      return 'a bumpy day so far';
    }();
    return '$greeting — $signal.';
  }

  String _body({
    required DailyNarrativeInput input,
    required GlucoseUnit unit,
    required bool resistant,
    required bool sensitive,
    required bool early,
  }) {
    final sentences = <String>[];

    // 1. Where you are right now + which way you're heading.
    final current = input.currentMgdl;
    if (current != null) {
      final g = _glucose(current, unit);
      final phrase = _trendPhrase(input.trend);
      if (phrase.isEmpty) {
        sentences.add('You\'re currently at $g.');
      } else {
        sentences.add('You\'re at $g and $phrase.');
      }
    } else {
      sentences.add('There\'s no live reading right now.');
    }

    // 2. Today's shape so far — but stay humble when it's still early.
    final m = input.todayMetrics;
    if (early || m.readingCount == 0) {
      sentences.add(
          'It\'s still early in the day, so there isn\'t much to read into yet.');
    } else {
      final tir = (m.timeInRange * 100).round();
      final mean = _glucose(m.meanMgdl, unit);
      sentences.add(
          'So far today you\'ve been in range $tir% of the time, averaging $mean.');
    }

    // 3. Why today might behave differently — the sensitivity drivers.
    final reasons = input.sensitivity.reasons;
    final because = reasons.isEmpty ? '' : ' (${reasons.join(', ')})';
    if (resistant) {
      sentences.add(
          'Your body\'s running a little insulin-resistant today$because, so insulin may work slower than usual.');
    } else if (sensitive) {
      sentences.add(
          'You\'re more insulin-sensitive than usual today$because, so doses may hit a bit harder.');
    }

    // 4. Sick-day colour, only when relevant.
    if (input.illnessActive) {
      sentences.add(
          'Being unwell tends to push your numbers and insulin needs up, so expect a firmer day.');
    }

    // Keep the story to at most four sentences.
    final trimmed = sentences.take(4).toList();
    return trimmed.join(' ');
  }

  List<String> _suggestions({
    required DailyNarrativeInput input,
    required GlucoseUnit unit,
    required bool resistant,
    required bool sensitive,
    required bool lowLooming,
    required bool highLooming,
    required double? predictedLow,
  }) {
    final out = <String>[];

    // Safety-critical first: an incoming low.
    if (lowLooming) {
      out.add(
          'Watch for a low around now — a quick ~15g of carbs would head it off.');
    }

    // Sick-day guidance.
    if (input.illnessActive) {
      out.add(
          'Stay hydrated and check ketones if you\'re running high — sick days raise your insulin needs.');
    }

    // Resistance → stronger, earlier bolusing.
    if (resistant) {
      out.add(
          'You\'re running resistant today, so a slightly stronger bolus and pre-bolusing a little earlier may help.');
    }

    // Delayed-low risk after drinking.
    if (input.alcoholYesterday) {
      out.add(
          'After yesterday\'s drinks, keep an eye out for delayed lows, especially overnight.');
    }

    // A building high (only worth saying if we aren't already coaching resistance).
    if (highLooming && !resistant) {
      out.add(
          'A high looks to be building — pre-bolusing a touch earlier for your next meal can soften it.');
    }

    // Heightened sensitivity → ease off.
    if (sensitive) {
      out.add(
          'You\'re more sensitive today, so ease off corrections a little and pre-bolus a touch less.');
    }

    // Never more than three — lead with the most important.
    return out.take(3).toList();
  }

  /// mg/dL trend arrow → warm plain-English phrase. Empty means "no arrow worth
  /// mentioning" (the caller falls back to a plainer sentence).
  String _trendPhrase(GlucoseTrend trend) => switch (trend) {
        GlucoseTrend.doubleUp => 'climbing fast',
        GlucoseTrend.singleUp => 'rising',
        GlucoseTrend.fortyFiveUp => 'drifting up',
        GlucoseTrend.flat => 'holding steady',
        GlucoseTrend.fortyFiveDown => 'easing down',
        GlucoseTrend.singleDown => 'falling',
        GlucoseTrend.doubleDown => 'dropping fast',
        GlucoseTrend.unknown => '',
      };

  /// Render a mg/dL value with its unit label, e.g. "6.2 mmol/L" or "112 mg/dL".
  String _glucose(double mgdl, GlucoseUnit unit) =>
      '${Mgdl(mgdl).display(unit)} ${unit.label}';
}
