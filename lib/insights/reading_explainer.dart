/// "Explain this reading": ranked causal hypotheses for a past high/low glucose
/// reading, each acceptable as a one-tap [Annotation] that feeds the retraining
/// pipeline (see `lib/feedback/`).
///
/// Pure Dart, deterministic, and built on the existing engines — [MealDetector],
/// [CompressionLowDetector], [IobCalculator], and [CarbModel] — rather than
/// reimplementing any physiology. Each hypothesis is scored 0..1 by plausibility,
/// ranked, and truncated so the UI shows only the few explanations that actually
/// fit the data.
library;

import '../analytics/carb_math.dart';
import '../analytics/insulin_math.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../feedback/annotations.dart';
import '../ml/event_detectors.dart';

/// The causal hypothesis behind an explanation. Richer than [AnnotationKind]
/// (stacking and "unexplained" have no dedicated annotation kind) but maps onto
/// it for the one-tap accept flow.
enum ExplanationKind {
  missedCarbs,
  compressionLow,
  siteFailure,
  exercise,
  insulinStacking,
  underbolusedMeal,
  unexplained;

  AnnotationKind get annotationKind => switch (this) {
        ExplanationKind.missedCarbs => AnnotationKind.missedCarbs,
        ExplanationKind.compressionLow => AnnotationKind.compressionLow,
        ExplanationKind.siteFailure => AnnotationKind.siteFailure,
        ExplanationKind.exercise => AnnotationKind.exercise,
        ExplanationKind.insulinStacking => AnnotationKind.other,
        ExplanationKind.underbolusedMeal => AnnotationKind.extraCarbs,
        ExplanationKind.unexplained => AnnotationKind.other,
      };

  String get label => switch (this) {
        ExplanationKind.missedCarbs => 'Unannounced carbs',
        ExplanationKind.compressionLow => 'Compression low',
        ExplanationKind.siteFailure => 'Possible site failure',
        ExplanationKind.exercise => 'Activity effect',
        ExplanationKind.insulinStacking => 'Insulin stacking',
        ExplanationKind.underbolusedMeal => 'Underbolused meal',
        ExplanationKind.unexplained => 'No clear cause',
      };
}

/// One ranked causal explanation for a reading.
class Explanation {
  const Explanation({
    required this.kind,
    required this.title,
    required this.detail,
    required this.score,
    this.suggestedAnnotation,
  });

  final ExplanationKind kind;
  final String title;

  /// Plain-language, quantified where the data allows it.
  final String detail;

  /// 0..1 plausibility. Not a probability — a ranking weight.
  final double score;

  /// Pre-filled annotation for one-tap accept; null for the fallback (there is
  /// nothing useful to feed the retraining pipeline when nothing fits).
  final Annotation? suggestedAnnotation;
}

/// Evaluates a fixed set of causal hypotheses around a past reading and returns
/// the ones that plausibly fit, best first.
class ReadingExplainer {
  ReadingExplainer({
    this.unit = GlucoseUnit.mmol,
    InsulinModel? insulinModel,
    MealDetector? mealDetector,
    CompressionLowDetector? compressionLowDetector,
    CarbModel? carbModel,
  })  : _iob = IobCalculator(model: insulinModel ?? InsulinModel.rapidActing),
        _meals = mealDetector ?? MealDetector(insulinModel: insulinModel),
        _compression = compressionLowDetector ??
            CompressionLowDetector(insulinModel: insulinModel),
        _carbModel = carbModel ?? const CarbModel();

  /// Unit used only for the human-readable [Explanation.detail] strings; all
  /// math stays in mg/dL.
  final GlucoseUnit unit;

  final IobCalculator _iob;
  final MealDetector _meals;
  final CompressionLowDetector _compression;
  final CarbModel _carbModel;

  /// Explanations are dropped below this plausibility.
  static const double minScore = 0.15;

  /// At most this many explanations are returned.
  static const int maxExplanations = 4;

  /// The fallback "unexplained" score when nothing else fits.
  static const double fallbackScore = 0.2;

  /// Reading counts as "low" below this for the low-specific hypotheses.
  static const double _lowGateMgdl = 80;

  List<Explanation> explain({
    required DateTime at,
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
    bool wasAsleep = false,
  }) {
    // Work on a bounded, clean, sorted slice around the reading.
    final windowStart = at.subtract(const Duration(hours: 4));
    final windowEnd = at.add(const Duration(minutes: 45));
    final window = [...cgm]
      ..removeWhere((s) =>
          s.sensorWarmup ||
          s.mgdl <= 0 ||
          s.time.isBefore(windowStart) ||
          s.time.isAfter(windowEnd))
      ..sort((a, b) => a.time.compareTo(b.time));

    final readingMgdl = _bgAt(window, at);

    // Meal candidates are shared between the missed-carbs and site-failure
    // hypotheses (a site failure and an unannounced meal look similar to the
    // rise detector; site failure is damped, not killed, when meals compete).
    final mealCandidates = _meals
        .detect(cgm: window, boluses: boluses, basal: basal, settings: settings)
        .where((c) =>
            !c.time.isBefore(at.subtract(const Duration(hours: 3))) &&
            !c.time.isAfter(at))
        .toList();

    final hypotheses = <Explanation?>[
      _missedCarbs(at, window, carbs, settings, mealCandidates),
      _compressionLow(
          at, window, boluses, basal, settings, wasAsleep, readingMgdl),
      _siteFailure(
          at, window, boluses, basal, carbs, settings, mealCandidates),
      _exercise(at, window, boluses, basal, settings, wasAsleep, readingMgdl),
      _insulinStacking(at, boluses, basal, settings, readingMgdl),
      _underbolusedMeal(at, window, boluses, basal, carbs, settings),
    ];

    final ranked = hypotheses.whereType<Explanation>().toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final kept =
        ranked.where((e) => e.score >= minScore).take(maxExplanations).toList();

    if (kept.isEmpty) return [_fallback(at)];
    return kept;
  }

  // ---------------------------------------------------------------------------
  // Hypotheses
  // ---------------------------------------------------------------------------

  /// (a) Unannounced / missed carbs: the meal detector found an unexplained
  /// sustained rise, and no carb entry accounts for it.
  Explanation? _missedCarbs(
    DateTime at,
    List<CgmSample> window,
    List<CarbEntry> carbs,
    TherapySettings settings,
    List<MealCandidate> mealCandidates,
  ) {
    // Candidates already announced on the pump are not "missed".
    final unannounced = mealCandidates
        .where((c) => !carbs.any((e) =>
            e.grams > 0 &&
            e.time.difference(c.time).inMinutes.abs() <= 45))
        .toList();
    if (unannounced.isEmpty) return null;

    final grams = unannounced.fold<double>(
        0, (sum, c) => sum + c.estimatedCarbsGrams);
    final maxConf = unannounced
        .map((c) => c.confidence)
        .reduce((a, b) => a > b ? a : b);
    // Repeated detections along the same rise reinforce the hypothesis.
    final score =
        (maxConf + 0.15 * (unannounced.length - 1)).clamp(0.0, 0.95).toDouble();

    final first = unannounced.first;
    final startBg = _bgAt(window, first.time);
    final endBg = _bgAt(window, at);
    final riseText = (startBg != null && endBg != null && endBg > startBg)
        ? 'Glucose rose ~${_delta(endBg - startBg)} between '
            '${_hhmm(first.time)} and ${_hhmm(at)}'
        : 'Glucose rose steadily from ${_hhmm(first.time)}';

    return Explanation(
      kind: ExplanationKind.missedCarbs,
      title: ExplanationKind.missedCarbs.label,
      detail: '$riseText with no matching carb entry — the pace of the climb is '
          'consistent with roughly ${grams.round()} g of unannounced carbs.',
      score: score,
      suggestedAnnotation: Annotation(
        id: _annotationId(ExplanationKind.missedCarbs, at),
        kind: AnnotationKind.missedCarbs,
        start: first.time,
        end: at,
        carbsGrams: grams.roundToDouble(),
        note: 'Suggested by Explain this reading',
        confidence: score,
      ),
    );
  }

  /// (b) Compression low: asleep, reading low, and the V-shaped drop/rebound is
  /// too fast for the insulin on board to explain.
  Explanation? _compressionLow(
    DateTime at,
    List<CgmSample> window,
    List<BolusEvent> boluses,
    List<BasalSegment> basal,
    TherapySettings settings,
    bool wasAsleep,
    double? readingMgdl,
  ) {
    if (!wasAsleep) return null;
    if (readingMgdl == null || readingMgdl >= _lowGateMgdl) return null;

    final events = _compression
        .detect(
          cgm: window,
          boluses: boluses,
          basal: basal,
          settings: settings,
          isAsleep: (_) => true,
        )
        .where((e) => e.start.difference(at).inMinutes.abs() <= 45)
        .toList();
    if (events.isEmpty) return null;

    final best =
        events.reduce((a, b) => a.confidence >= b.confidence ? a : b);
    // A confirmed drop+rebound signature is strong evidence even at moderate
    // detector confidence, hence the floor.
    final score = (0.4 + 0.6 * best.confidence).clamp(0.0, 0.95).toDouble();

    return Explanation(
      kind: ExplanationKind.compressionLow,
      title: ExplanationKind.compressionLow.label,
      detail: 'Dipped to ${_bg(best.nadir)} and snapped back '
          '~${_delta(best.reboundMgdlPerMin * 5)} within 5 minutes — far faster '
          'than insulin on board can explain. Classic sensor compression while '
          'sleeping, not a true low.',
      score: score,
      suggestedAnnotation: Annotation(
        id: _annotationId(ExplanationKind.compressionLow, at),
        kind: AnnotationKind.compressionLow,
        start: best.start.subtract(const Duration(minutes: 10)),
        end: at.add(const Duration(minutes: 30)),
        note: 'Suggested by Explain this reading',
        confidence: score,
      ),
    );
  }

  /// (c) Site failure: a sustained ≥2 h rise with meaningful insulin activity
  /// that visibly did nothing. Damped (not excluded) when a meal candidate or
  /// announced carbs offer a competing story.
  Explanation? _siteFailure(
    DateTime at,
    List<CgmSample> window,
    List<BolusEvent> boluses,
    List<BasalSegment> basal,
    List<CarbEntry> carbs,
    TherapySettings settings,
    List<MealCandidate> mealCandidates,
  ) {
    const lookback = Duration(minutes: 150);
    final from = at.subtract(lookback);
    final startBg = _bgAt(window, from);
    final endBg = _bgAt(window, at);
    if (startBg == null || endBg == null) return null;

    final observedRise = endBg - startBg;
    if (observedRise < 40) return null;

    final expectedDrop = _expectedInsulinDropMgdl(from, at, boluses, basal, settings);
    if (expectedDrop < 30) return null; // no meaningful IOB activity → not a site story

    // Glucose must not be responding: flat-or-rising over the last hour.
    final hourAgoBg = _bgAt(window, at.subtract(const Duration(hours: 1)));
    if (hourAgoBg != null && endBg - hourAgoBg < -10) return null;

    // Anomaly: the gap between what insulin should have done and what happened.
    final unexplained = observedRise + expectedDrop;
    var score = (unexplained / 180).clamp(0.0, 1.0).toDouble();
    final carbsInWindow = carbs.any((e) =>
        e.grams > 0 && !e.time.isBefore(from) && !e.time.isAfter(at));
    if (carbsInWindow) {
      score *= 0.4; // an announced meal is the likelier culprit
    } else if (mealCandidates.isNotEmpty) {
      score *= 0.65; // an unannounced meal competes, but can't be confirmed
    }
    score = score.clamp(0.0, 0.95).toDouble();
    if (score < minScore) return null;

    final seg = settings.segmentAt(at);
    final absorbedUnits = expectedDrop / seg.isf;

    return Explanation(
      kind: ExplanationKind.siteFailure,
      title: ExplanationKind.siteFailure.label,
      detail: 'Glucose climbed ${_delta(observedRise)} over the last '
          '${_hoursText(lookback)} even though roughly '
          '${absorbedUnits.toStringAsFixed(1)} U of insulin was absorbed in that '
          'window (expected ~${_delta(expectedDrop)} of drop). Insulin appears '
          'ineffective — check the infusion site/set.',
      score: score,
      suggestedAnnotation: Annotation(
        id: _annotationId(ExplanationKind.siteFailure, at),
        kind: AnnotationKind.siteFailure,
        start: from,
        end: at,
        note: 'Suggested by Explain this reading',
        confidence: score,
      ),
    );
  }

  /// (d) Exercise / activity: a steep fall mostly unexplained by insulin
  /// activity. Strongly damped while asleep (compression is likelier).
  Explanation? _exercise(
    DateTime at,
    List<CgmSample> window,
    List<BolusEvent> boluses,
    List<BasalSegment> basal,
    TherapySettings settings,
    bool wasAsleep,
    double? readingMgdl,
  ) {
    const lookback = Duration(minutes: 90);
    final from = at.subtract(lookback);
    final startBg = _bgAt(window, from);
    final endBg = readingMgdl ?? _bgAt(window, at);
    if (startBg == null || endBg == null) return null;

    final observedFall = startBg - endBg;
    if (observedFall < 40) return null;

    final expectedDrop = _expectedInsulinDropMgdl(from, at, boluses, basal, settings);
    final unexplained = observedFall - expectedDrop;
    if (unexplained < 25 || unexplained / observedFall < 0.5) return null;

    var score = (unexplained / 80).clamp(0.0, 1.0) * 0.9;
    if (wasAsleep) score *= 0.3;
    score = score.clamp(0.0, 0.95).toDouble();
    if (score < minScore) return null;

    return Explanation(
      kind: ExplanationKind.exercise,
      title: ExplanationKind.exercise.label,
      detail: 'Fell ${_delta(observedFall)} in ${_hoursText(lookback)}, but '
          'insulin on board explains only ~${_delta(expectedDrop)} of that. '
          'An unlogged activity or exercise effect is the likely driver.',
      score: score,
      suggestedAnnotation: Annotation(
        id: _annotationId(ExplanationKind.exercise, at),
        kind: AnnotationKind.exercise,
        start: from,
        end: at,
        note: 'Suggested by Explain this reading',
        confidence: score,
      ),
    );
  }

  /// (e) Insulin stacking: overlapping boluses left a lot of insulin active
  /// heading into a low.
  Explanation? _insulinStacking(
    DateTime at,
    List<BolusEvent> boluses,
    List<BasalSegment> basal,
    TherapySettings settings,
    double? readingMgdl,
  ) {
    if (readingMgdl == null || readingMgdl >= _lowGateMgdl) return null;

    final recent = boluses
        .where((b) =>
            b.units > 0 &&
            b.time.isBefore(at) &&
            at.difference(b.time).inHours < 4)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (recent.length < 2) return null;

    // "Stacking" needs at least one overlapping pair, not just two distant doses.
    var overlaps = false;
    for (var i = 1; i < recent.length; i++) {
      if (recent[i].time.difference(recent[i - 1].time).inMinutes <= 150) {
        overlaps = true;
        break;
      }
    }
    if (!overlaps) return null;

    final checkpoint = at.subtract(const Duration(minutes: 30));
    final iob = _iob.total(recent, basal, checkpoint);
    final seg = settings.segmentAt(at);
    final potentialDrop = iob.units * seg.isf;
    if (potentialDrop < 60) return null;

    final score = ((potentialDrop / 120).clamp(0.0, 1.0) * 0.95).toDouble();
    final totalUnits = recent.fold<double>(0, (sum, b) => sum + b.units);

    return Explanation(
      kind: ExplanationKind.insulinStacking,
      title: ExplanationKind.insulinStacking.label,
      detail: '${recent.length} boluses totalling ${totalUnits.toStringAsFixed(1)} U '
          'between ${_hhmm(recent.first.time)} and ${_hhmm(recent.last.time)} '
          'overlapped: ${iob.units.toStringAsFixed(1)} U was still active 30 min '
          'before this low — enough to lower glucose another '
          '~${_delta(potentialDrop)}.',
      score: score,
      suggestedAnnotation: Annotation(
        id: _annotationId(ExplanationKind.insulinStacking, at),
        kind: AnnotationKind.other,
        start: recent.first.time,
        end: at,
        note: 'Insulin stacking before a low (suggested by Explain this reading)',
        confidence: score,
      ),
    );
  }

  /// (f) Underbolused / underestimated meal: carbs were entered, but the
  /// observed rise far exceeds the modelled net effect of those carbs minus
  /// the insulin taken for them.
  Explanation? _underbolusedMeal(
    DateTime at,
    List<CgmSample> window,
    List<BolusEvent> boluses,
    List<BasalSegment> basal,
    List<CarbEntry> carbs,
    TherapySettings settings,
  ) {
    Explanation? best;
    for (final entry in carbs) {
      if (entry.grams <= 0) continue;
      final age = at.difference(entry.time).inMinutes;
      if (age < 20 || age > 210) continue;

      final startBg = _bgAt(window, entry.time);
      final endBg = _bgAt(window, at);
      if (startBg == null || endBg == null) continue;

      final observedRise = endBg - startBg;
      if (observedRise < 50) continue;

      final seg = settings.segmentAt(entry.time);
      final csf =
          carbSensitivityFactor(isf: seg.isf, carbRatio: seg.carbRatio);
      final carbRise = _modelledCarbRiseMgdl(entry, entry.time, at, csf);
      final insulinDrop =
          _expectedInsulinDropMgdl(entry.time, at, boluses, basal, settings);
      final excess = observedRise - (carbRise - insulinDrop);
      if (excess < 40) continue;

      final extraGrams = csf <= 0 ? 0.0 : excess / csf;
      final score =
          ((excess / 120).clamp(0.0, 1.0) * 0.85).clamp(0.0, 0.95).toDouble();
      if (best != null && score <= best.score) continue;

      best = Explanation(
        kind: ExplanationKind.underbolusedMeal,
        title: ExplanationKind.underbolusedMeal.label,
        detail: 'You logged ${entry.grams.round()} g at ${_hhmm(entry.time)}, '
            'but glucose rose ${_delta(observedRise)} — about '
            '${_delta(excess)} more than the model expects for that entry. '
            'Roughly ${extraGrams.round()} g looks uncovered (underestimated '
            'carbs or an underbolus).',
        score: score,
        suggestedAnnotation: Annotation(
          id: _annotationId(ExplanationKind.underbolusedMeal, at),
          kind: AnnotationKind.extraCarbs,
          start: entry.time,
          end: at,
          carbsGrams: extraGrams.roundToDouble(),
          note: 'Suggested by Explain this reading',
          confidence: score,
        ),
      );
    }
    return best;
  }

  /// (g) Fallback when nothing fits.
  Explanation _fallback(DateTime at) => Explanation(
        kind: ExplanationKind.unexplained,
        title: ExplanationKind.unexplained.label,
        detail: 'Nothing in the pump or CGM history around ${_hhmm(at)} stands '
            'out. Possible drivers the engine cannot see: stress, hormones, a '
            'slowly failing set, or sensor noise.',
        score: fallbackScore,
        suggestedAnnotation: null,
      );

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  /// Nearest clean sample within 20 minutes of [t], or null.
  double? _bgAt(List<CgmSample> sorted, DateTime t) {
    CgmSample? best;
    var bestMinutes = 21;
    for (final s in sorted) {
      final d = s.time.difference(t).inMinutes.abs();
      if (d < bestMinutes) {
        best = s;
        bestMinutes = d;
      }
    }
    return best?.mgdl;
  }

  /// mg/dL of glucose-lowering the insulin activity should have produced over
  /// [from, to), integrated at 5-minute steps.
  double _expectedInsulinDropMgdl(
    DateTime from,
    DateTime to,
    List<BolusEvent> boluses,
    List<BasalSegment> basal,
    TherapySettings settings,
  ) {
    var drop = 0.0;
    var t = from;
    while (t.isBefore(to)) {
      final seg = settings.segmentAt(t);
      final act = _iob.total(boluses, basal, t).activityUnitsPerMin;
      drop += act * seg.isf * 5;
      t = t.add(const Duration(minutes: 5));
    }
    return drop;
  }

  /// Modelled glucose rise from one carb entry between [from] and [to].
  double _modelledCarbRiseMgdl(
    CarbEntry entry,
    DateTime from,
    DateTime to,
    double csf,
  ) {
    final td = entry.absorptionMinutes.toDouble();
    double absorbedAt(DateTime t) =>
        1 - _carbModel.cobFraction(t.difference(entry.time).inMinutes.toDouble(), td);
    return (absorbedAt(to) - absorbedAt(from)) * entry.grams * csf;
  }

  String _annotationId(ExplanationKind kind, DateTime at) =>
      'explain-${kind.name}-${at.millisecondsSinceEpoch}';

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _hoursText(Duration d) {
    final h = d.inMinutes / 60;
    return h == h.roundToDouble() ? '${h.round()} h' : '${h.toStringAsFixed(1)} h';
  }

  /// A glucose *level* in the display unit.
  String _bg(double mgdl) => '${Mgdl(mgdl).display(unit)} ${unit.label}';

  /// A glucose *delta* in the display unit.
  String _delta(double mgdl) => switch (unit) {
        GlucoseUnit.mgdl => '${mgdl.round()} mg/dL',
        GlucoseUnit.mmol => '${(mgdl / kMgdlPerMmol).toStringAsFixed(1)} mmol/L',
      };
}
