/// Meal library: saved meals with per-meal *learned* absorption profiles and a
/// bounded outcome history, plus damped learning from observed post-meal CGM curves.
///
/// Pure Dart (no Flutter/drift imports) so it is unit-testable off-device like the
/// rest of the domain layer. Persistence lives in `data/meal_tables.dart`; the
/// pre-bolus coach (`meals/prebolus_coach.dart`) consumes the learned curves.
///
/// Learning model: the bilinear carb model (`analytics/carb_math.dart`) has its
/// absorption-rate peak at half the absorption time, and in practice the post-meal
/// BG peak lands near that rate peak. So from an observed BG peak at +P minutes we
/// estimate absorption ≈ 2·P, then blend only 30% toward the new observation
/// (damped learning — one weird pizza night doesn't rewrite the curve) and clamp to
/// physiologically plausible bounds (60..360 min).
library;

import '../core/samples.dart';
import '../core/units.dart';

/// Rough meal buckets, used for the library UI and a default emoji.
enum MealCategory {
  breakfast,
  lunch,
  dinner,
  snack,
  takeaway,
  dessert,
  other;

  String get label => name;

  String get defaultEmoji => switch (this) {
        MealCategory.breakfast => '🥣',
        MealCategory.lunch => '🥪',
        MealCategory.dinner => '🍝',
        MealCategory.snack => '🍎',
        MealCategory.takeaway => '🍕',
        MealCategory.dessert => '🍰',
        MealCategory.other => '🍽️',
      };
}

/// What actually happened one time this meal was eaten, computed post-hoc from CGM.
class MealOutcome {
  const MealOutcome({
    required this.eatenAt,
    required this.preBolusMinutes,
    required this.bolusUnits,
    required this.bgAtMealMgdl,
    required this.peakMgdl,
    required this.peakOffsetMinutes,
    required this.bgAt3hMgdl,
    required this.timeAbove180Minutes,
  });

  final DateTime eatenAt;

  /// Minutes the bolus actually preceded eating (0 = bolused at/after first bite).
  final int preBolusMinutes;

  final double bolusUnits;

  /// Glucose at (nearest CGM sample to) the moment of eating.
  final double bgAtMealMgdl;

  /// Highest glucose in the 3 h after eating, and when it occurred.
  final double peakMgdl;
  final int peakOffsetMinutes;

  /// Glucose at +3 h — "did it come back down?".
  final double bgAt3hMgdl;

  /// Minutes spent above 180 mg/dL (10.0 mmol/L) in the 3 h after eating.
  final int timeAbove180Minutes;

  /// Builds an outcome post-hoc from the CGM trace around the meal. [postMealCgm]
  /// should span at least [eatenAt] .. +3 h; samples outside that window are ignored
  /// (a little pre-meal context helps pin the starting BG).
  factory MealOutcome.fromCgm({
    required DateTime eatenAt,
    required int preBolusMinutes,
    required double bolusUnits,
    required List<CgmSample> postMealCgm,
  }) {
    final samples = [...postMealCgm]..sort((a, b) => a.time.compareTo(b.time));
    final windowEnd = eatenAt.add(const Duration(hours: 3));

    // BG at meal: nearest sample to eatenAt.
    var bgAtMeal = samples.isEmpty ? 0.0 : samples.first.mgdl;
    var bestGap = const Duration(days: 1);
    for (final s in samples) {
      final gap = s.time.difference(eatenAt).abs();
      if (gap < bestGap) {
        bestGap = gap;
        bgAtMeal = s.mgdl;
      }
    }

    // Peak, its offset, and time-above-180 within the 3 h window.
    var peak = bgAtMeal;
    var peakOffset = 0;
    var aboveMinutes = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.time.isBefore(eatenAt) || s.time.isAfter(windowEnd)) continue;
      final offset = s.time.difference(eatenAt).inMinutes;
      if (s.mgdl > peak) {
        peak = s.mgdl;
        peakOffset = offset;
      }
      if (s.mgdl > GlucoseThresholds.high) {
        // Credit this sample with the gap to the next one (capped — CGM gaps happen).
        var dt = 5.0;
        if (i + 1 < samples.length) {
          dt = samples[i + 1]
              .time
              .difference(s.time)
              .inMinutes
              .toDouble()
              .clamp(1.0, 10.0);
        }
        aboveMinutes += dt;
      }
    }

    // BG at +3 h: nearest sample to the window end.
    var bgAt3h = peak;
    bestGap = const Duration(days: 1);
    for (final s in samples) {
      final gap = s.time.difference(windowEnd).abs();
      if (gap < bestGap) {
        bestGap = gap;
        bgAt3h = s.mgdl;
      }
    }

    return MealOutcome(
      eatenAt: eatenAt,
      preBolusMinutes: preBolusMinutes,
      bolusUnits: bolusUnits,
      bgAtMealMgdl: bgAtMeal,
      peakMgdl: peak,
      peakOffsetMinutes: peakOffset,
      bgAt3hMgdl: bgAt3h,
      timeAbove180Minutes: aboveMinutes.round(),
    );
  }

  Map<String, dynamic> toJson() => {
        'eatenAt': eatenAt.toIso8601String(),
        'preBolusMinutes': preBolusMinutes,
        'bolusUnits': bolusUnits,
        'bgAtMealMgdl': bgAtMealMgdl,
        'peakMgdl': peakMgdl,
        'peakOffsetMinutes': peakOffsetMinutes,
        'bgAt3hMgdl': bgAt3hMgdl,
        'timeAbove180Minutes': timeAbove180Minutes,
      };

  factory MealOutcome.fromJson(Map<String, dynamic> json) => MealOutcome(
        eatenAt: DateTime.parse(json['eatenAt'] as String),
        preBolusMinutes: (json['preBolusMinutes'] as num).toInt(),
        bolusUnits: (json['bolusUnits'] as num).toDouble(),
        bgAtMealMgdl: (json['bgAtMealMgdl'] as num).toDouble(),
        peakMgdl: (json['peakMgdl'] as num).toDouble(),
        peakOffsetMinutes: (json['peakOffsetMinutes'] as num).toInt(),
        bgAt3hMgdl: (json['bgAt3hMgdl'] as num).toDouble(),
        timeAbove180Minutes: (json['timeAbove180Minutes'] as num).toInt(),
      );
}

/// A meal the user eats repeatedly, carrying its personally learned curve.
class SavedMeal {
  const SavedMeal({
    required this.id,
    required this.name,
    this.emoji = '🍽️',
    this.category = MealCategory.other,
    required this.carbsGrams,
    this.fatGrams = 0,
    this.proteinGrams = 0,
    this.fatProteinHeavy = false,
    this.fatProteinTailScore = 0,
    this.absorptionMinutes = 180,
    this.peakOffsetMinutes = 90,
    this.outcomes = const [],
  });

  /// Outcome history is bounded to the most recent [maxOutcomes].
  static const int maxOutcomes = 20;

  /// Learned-parameter bounds (physiological plausibility, mirrors the clamps the
  /// carb model itself applies).
  static const int minAbsorptionMinutes = 60;
  static const int maxAbsorptionMinutes = 360;
  static const int minPeakOffsetMinutes = 30;
  static const int maxPeakOffsetMinutes = 180;

  /// TASK-153: a learned score at/above this counts as fat/protein-heavy for the
  /// coaches, same role as the manual [fatProteinHeavy] flag.
  static const double fatProteinHeavyThreshold = 0.5;

  final String id;
  final String name;
  final String emoji;
  final MealCategory category;
  final double carbsGrams;

  /// Optional macros for fat-protein-unit dosing (0 = unknown). When present the FPU
  /// coach can advise a split/extended bolus for the delayed fat/protein rise.
  final double fatGrams;
  final double proteinGrams;

  /// User-set fat/protein-heavy flag (the "pizza effect" — late, long absorption).
  /// Always wins over [fatProteinTailScore] when true; see [effectiveFatProteinHeavy].
  final bool fatProteinHeavy;

  /// TASK-153: learned fat/protein-tail signature in [0, 1], derived from the
  /// outcome history's late-peak + still-elevated-at-3h pattern (see
  /// [MealLibrary.learnFromOutcome]) — the "pizza effect" the app can spot on its
  /// own once enough outcomes are logged, without the user remembering to flag it.
  final double fatProteinTailScore;

  /// Learned absorption duration for the bilinear carb model. Starts at the
  /// app-wide default of 180 min and drifts toward what CGM actually shows.
  final int absorptionMinutes;

  /// Learned minutes from eating to the post-meal BG peak.
  final int peakOffsetMinutes;

  /// TASK-153: whether the coaches should treat this meal as fat/protein-heavy —
  /// the manual flag always wins when the user has set it; otherwise the learned
  /// score decides once it's crossed [fatProteinHeavyThreshold].
  bool get effectiveFatProteinHeavy =>
      fatProteinHeavy || fatProteinTailScore >= fatProteinHeavyThreshold;

  /// Most recent outcomes, ascending by [MealOutcome.eatenAt].
  final List<MealOutcome> outcomes;

  SavedMeal copyWith({
    String? name,
    String? emoji,
    MealCategory? category,
    double? carbsGrams,
    double? fatGrams,
    double? proteinGrams,
    bool? fatProteinHeavy,
    double? fatProteinTailScore,
    int? absorptionMinutes,
    int? peakOffsetMinutes,
    List<MealOutcome>? outcomes,
  }) =>
      SavedMeal(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        category: category ?? this.category,
        carbsGrams: carbsGrams ?? this.carbsGrams,
        fatGrams: fatGrams ?? this.fatGrams,
        proteinGrams: proteinGrams ?? this.proteinGrams,
        fatProteinHeavy: fatProteinHeavy ?? this.fatProteinHeavy,
        fatProteinTailScore: fatProteinTailScore ?? this.fatProteinTailScore,
        absorptionMinutes: absorptionMinutes ?? this.absorptionMinutes,
        peakOffsetMinutes: peakOffsetMinutes ?? this.peakOffsetMinutes,
        outcomes: outcomes ?? this.outcomes,
      );

  /// Returns a copy with [outcome] recorded, keeping only the most recent
  /// [maxOutcomes] entries.
  SavedMeal withOutcome(MealOutcome outcome) {
    final all = [...outcomes, outcome]
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final trimmed = all.length > maxOutcomes
        ? all.sublist(all.length - maxOutcomes)
        : all;
    return copyWith(outcomes: trimmed);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'category': category.name,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'proteinGrams': proteinGrams,
        'fatProteinHeavy': fatProteinHeavy,
        'fatProteinTailScore': fatProteinTailScore,
        'absorptionMinutes': absorptionMinutes,
        'peakOffsetMinutes': peakOffsetMinutes,
        'outcomes': [for (final o in outcomes) o.toJson()],
      };

  factory SavedMeal.fromJson(Map<String, dynamic> json) => SavedMeal(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '🍽️',
        category: MealCategory.values.asNameMap()[json['category']] ??
            MealCategory.other,
        // TASK-250: grams/minutes are physically non-negative and, being read from a
        // persisted blob, must not let a corrupt row turn into a negative or
        // astronomically large meal flowing unchecked into dosing-adjacent code.
        carbsGrams: _clampNonNegative((json['carbsGrams'] as num).toDouble()),
        fatGrams: _clampNonNegative((json['fatGrams'] as num?)?.toDouble() ?? 0),
        proteinGrams:
            _clampNonNegative((json['proteinGrams'] as num?)?.toDouble() ?? 0),
        fatProteinHeavy: json['fatProteinHeavy'] as bool? ?? false,
        // TASK-250-style hardening: a learned [0,1] score must not carry a
        // corrupt/hostile out-of-range value into the coaches' threshold check.
        fatProteinTailScore: _clampUnit(
            (json['fatProteinTailScore'] as num?)?.toDouble() ?? 0),
        absorptionMinutes: _clampMinutes(
            (json['absorptionMinutes'] as num?)?.toInt() ?? 180,
            max: 600),
        peakOffsetMinutes:
            _clampMinutes((json['peakOffsetMinutes'] as num?)?.toInt() ?? 90, max: 300),
        outcomes: [
          for (final o in (json['outcomes'] as List? ?? const []))
            MealOutcome.fromJson((o as Map).cast<String, dynamic>()),
        ],
      );

  /// TASK-250: a food quantity (grams) is never negative; astronomically large
  /// values (a corrupt/hostile persisted row) are capped rather than passed through.
  static double _clampNonNegative(double v) =>
      v.isNaN ? 0 : v.clamp(0, 2000).toDouble();

  /// TASK-250: absorption/peak-offset minutes are positive and bounded — a corrupt
  /// row must not produce a meal whose modelled curve runs for years or backwards.
  static int _clampMinutes(int v, {required int max}) => v.clamp(1, max);

  /// TASK-153: a [0,1] score must not decode to NaN or an out-of-range value.
  static double _clampUnit(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);
}

/// Generates a compact unique-enough id for a personal, single-device library.
String newMealId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// IMMUTABLE meal collection (TASK-121) with fuzzy lookup, damped curve learning,
/// and plain-language insights. Every "mutator" returns a NEW instance with a
/// copied map, so Riverpod change detection and old references stay honest.
/// Persistence (KV) hydrates/writes through this.
class MealLibrary {
  MealLibrary({Iterable<SavedMeal> meals = const []})
      : _meals = {for (final m in meals) m.id: m};

  MealLibrary._(this._meals);

  /// Blend fraction toward each new observation. 0.3 = damped: three-ish
  /// consistent meals shift the curve most of the way, one outlier barely moves it.
  static const double learningRate = 0.3;

  /// TASK-153: fewer outcomes than this and the fat/protein-tail signature is
  /// noise, not a pattern — mirrors the outcomes>=3 confidence threshold the
  /// pre-bolus coach already uses to gate its own advice.
  static const int minOutcomesForFatProteinLearning = 3;

  final Map<String, SavedMeal> _meals;

  List<SavedMeal> get meals => List.unmodifiable(_meals.values);

  /// Insert or replace by id — returns a new library.
  MealLibrary add(SavedMeal meal) =>
      MealLibrary._({..._meals, meal.id: meal});

  /// Alias for [add]; reads better at call sites that edit an existing meal.
  MealLibrary update(SavedMeal meal) => add(meal);

  SavedMeal? findById(String id) => _meals[id];

  /// Fuzzy find by name: exact > substring (either direction) > word overlap.
  /// 'pizza' matches 'Pizza night'. Returns null when nothing scores well enough.
  SavedMeal? find(String query) {
    final ranked = search(query);
    return ranked.isEmpty ? null : ranked.first;
  }

  /// All meals matching [query], best match first. Empty query returns everything.
  List<SavedMeal> search(String query) {
    final q = _normalise(query);
    if (q.isEmpty) return meals;
    final scored = <(SavedMeal, double)>[];
    for (final m in _meals.values) {
      final score = _matchScore(q, _normalise(m.name));
      if (score >= 0.5) scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored) s.$1];
  }

  /// Records [outcome] on [meal] and re-estimates its absorption curve from the
  /// observed post-meal rise in [postMealCgm] (damped, bounded — see library doc).
  /// Returns the new library plus the updated meal (TASK-121: no in-place mutation).
  ({MealLibrary library, SavedMeal meal}) learnFromOutcome(
    SavedMeal meal,
    MealOutcome outcome,
    List<CgmSample> postMealCgm,
  ) {
    final current = _meals[meal.id] ?? meal;
    var updated = current.withOutcome(outcome);

    final observedPeak = _observedPeakOffsetMinutes(outcome.eatenAt, postMealCgm);
    if (observedPeak != null) {
      // BG peak ≈ absorption-rate peak at half the absorption time (bilinear model),
      // so observed absorption ≈ 2 × peak offset.
      final observedAbsorption = observedPeak * 2.0;
      final newPeak = _clampInt(
        (current.peakOffsetMinutes +
                learningRate * (observedPeak - current.peakOffsetMinutes))
            .round(),
        SavedMeal.minPeakOffsetMinutes,
        SavedMeal.maxPeakOffsetMinutes,
      );
      final newAbsorption = _clampInt(
        (current.absorptionMinutes +
                learningRate * (observedAbsorption - current.absorptionMinutes))
            .round(),
        SavedMeal.minAbsorptionMinutes,
        SavedMeal.maxAbsorptionMinutes,
      );
      updated = updated.copyWith(
        peakOffsetMinutes: newPeak,
        absorptionMinutes: newAbsorption,
      );
    }

    // TASK-153: once there's enough outcome history to trust it, re-derive the
    // fat/protein-tail signature from the median late-peak + still-elevated-at-3h
    // pattern and damped-blend it in, same as the peak/absorption learning above.
    if (updated.outcomes.length >= minOutcomesForFatProteinLearning) {
      final observedSignal = _fatProteinTailSignal(updated.outcomes);
      final newScore = (current.fatProteinTailScore +
              learningRate * (observedSignal - current.fatProteinTailScore))
          .clamp(0.0, 1.0);
      updated = updated.copyWith(fatProteinTailScore: newScore);
    }

    return (library: add(updated), meal: updated);
  }

  /// TASK-153: the fat/protein "pizza effect" signature is a LATE peak (well past
  /// the ~60-90 min a pure-carb meal typically peaks at) combined with glucose
  /// STILL elevated at +3 h relative to where it started — carb counting alone
  /// misses this because it only sees the (correctly-dosed) early rise. Uses the
  /// median across [outcomes] rather than the single latest one so one noisy meal
  /// can't swing the signal; the damped blend in [learnFromOutcome] then keeps the
  /// STORED score itself from swinging on a single re-derivation either.
  static double _fatProteinTailSignal(List<MealOutcome> outcomes) {
    final medianTail =
        _median([for (final o in outcomes) o.bgAt3hMgdl - o.bgAtMealMgdl]);
    final medianPeakOffset =
        _median([for (final o in outcomes) o.peakOffsetMinutes.toDouble()]);

    // 0 at a resolved tail (<=0 mg/dL above meal-time BG by +3h), 1.0 once still
    // 60+ mg/dL elevated.
    final tailSignal = (medianTail / 60.0).clamp(0.0, 1.0);
    // 0 at a typical ~60-min carb-only peak, 1.0 at 120+ min (clearly delayed).
    final peakSignal = ((medianPeakOffset - 60.0) / 60.0).clamp(0.0, 1.0);
    return (tailSignal + peakSignal) / 2.0;
  }

  /// Plain-language stats for the detail screen, e.g.
  /// 'Median peak 12.8 mmol/L at +75 min' / 'best result when pre-bolused ≥15 min'.
  List<String> mealInsights(SavedMeal meal) {
    final outcomes = meal.outcomes;
    if (outcomes.isEmpty) {
      return [
        'No outcomes recorded yet — log this meal a few times and the app will '
            'learn its personal curve.',
      ];
    }
    final insights = <String>[];
    const mmol = GlucoseUnit.mmol;

    final medianPeak = _median([for (final o in outcomes) o.peakMgdl]);
    final medianOffset =
        _median([for (final o in outcomes) o.peakOffsetMinutes.toDouble()]);
    insights.add(
        'Median peak ${Mgdl(medianPeak).display(mmol)} ${mmol.label} at '
        '+${medianOffset.round()} min (${outcomes.length} meals).');

    final medianAbove = _median(
        [for (final o in outcomes) o.timeAbove180Minutes.toDouble()]);
    if (medianAbove >= 5) {
      insights.add('Typically ${medianAbove.round()} min above '
          '${const Mgdl(GlucoseThresholds.high).display(mmol)} ${mmol.label} in the '
          '3 h after eating.');
    } else {
      insights.add('Usually stays under '
          '${const Mgdl(GlucoseThresholds.high).display(mmol)} ${mmol.label} for the '
          'full 3 h — nice.');
    }

    // Does pre-bolusing ≥15 min visibly help this meal?
    final long = [for (final o in outcomes) if (o.preBolusMinutes >= 15) o];
    final short = [for (final o in outcomes) if (o.preBolusMinutes < 15) o];
    if (long.isNotEmpty && short.isNotEmpty) {
      final longPeak = _median([for (final o in long) o.peakMgdl]);
      final shortPeak = _median([for (final o in short) o.peakMgdl]);
      if (longPeak < shortPeak - 9) {
        insights.add('Best results when pre-bolused ≥15 min: median peak '
            '${Mgdl(longPeak).display(mmol)} vs ${Mgdl(shortPeak).display(mmol)} '
            '${mmol.label}.');
      } else if (shortPeak < longPeak - 9) {
        insights.add('Longer pre-bolus has not helped this meal so far (median '
            'peak ${Mgdl(longPeak).display(mmol)} vs '
            '${Mgdl(shortPeak).display(mmol)} ${mmol.label}).');
      } else {
        insights.add('Pre-bolus timing has not clearly changed the peak yet — '
            'more data will sharpen this.');
      }
    }

    final medianTail = _median(
        [for (final o in outcomes) o.bgAt3hMgdl - o.bgAtMealMgdl]);
    if (medianTail > 27) {
      insights.add('Still ~${Mgdl(medianTail).display(mmol)} ${mmol.label} above '
          'pre-meal level at +3 h'
          '${meal.fatProteinHeavy ? ' — consider an extended/split bolus for the fat/protein tail' : ''}.');
    }

    return insights;
  }

  /// Minutes from eating to the observed BG peak, or null when the trace shows no
  /// meaningful rise (< 15 mg/dL) or has no usable baseline. Ignores the first 10
  /// minutes (sensor lag/noise) and anything past +210 min.
  int? _observedPeakOffsetMinutes(DateTime eatenAt, List<CgmSample> cgm) {
    const searchStartMinutes = 10;
    const searchEndMinutes = 210;

    double? baseline;
    var baselineGap = const Duration(minutes: 31);
    var peak = double.negativeInfinity;
    var peakOffset = -1;
    for (final s in cgm) {
      final gap = s.time.difference(eatenAt).abs();
      if (gap < baselineGap) {
        baselineGap = gap;
        baseline = s.mgdl;
      }
      final offset = s.time.difference(eatenAt).inMinutes;
      if (offset < searchStartMinutes || offset > searchEndMinutes) continue;
      if (s.mgdl > peak) {
        peak = s.mgdl;
        peakOffset = offset;
      }
    }
    if (baseline == null || peakOffset < 0) return null;
    if (peak - baseline < 15) return null; // no meaningful rise — don't learn
    return peakOffset;
  }

  static String _normalise(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static double _matchScore(String query, String name) {
    if (name == query) return 1.0;
    if (name.contains(query) || query.contains(name)) return 0.9;
    final queryWords = query.split(' ').toSet();
    final nameWords = name.split(' ').toSet();
    final overlap = queryWords.intersection(nameWords).length;
    if (overlap == 0) return 0.0;
    return 0.8 * overlap / queryWords.length;
  }
}

int _clampInt(int value, int lo, int hi) =>
    value < lo ? lo : (value > hi ? hi : value);

double _median(List<double> values) {
  assert(values.isNotEmpty);
  final sorted = [...values]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}
