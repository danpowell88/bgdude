/// Ask-your-data Q&A (issue #80): plain-English questions answered from facts the app
/// has ALREADY computed.
///
/// The governing rule is that the language model never produces a number. It receives a
/// sheet of computed facts, and its only job is to phrase them and say which fact backs
/// each statement. An answer containing a figure that isn't in the cited facts is
/// rejected outright rather than shown with a caveat.
///
/// That is deliberately stricter than "the model is usually accurate". This app sits
/// next to insulin dosing: a confidently-worded invented number is worse than no answer,
/// because the user has no way to tell it apart from a real one.
///
/// Everything here is pure, so the retrieval and the rejection rule are testable without
/// a model installed.
library;

import '../analytics/metrics.dart';

/// The fixed set of questions this feature answers (AC#3).
///
/// A closed taxonomy rather than open-ended chat: every kind maps to facts the app
/// already computes, so there is never a question whose answer would have to be
/// invented. Anything unrecognised is declined, not guessed at.
enum AskTopic {
  timeInRange,
  averageGlucose,
  lows,
  highs,
  variability,
  overnight,
  riskIndices,
  dataCoverage,
}

/// A window of time a question refers to.
enum AskPeriod { today, last7Days, last14Days, last30Days }

extension AskPeriodLabel on AskPeriod {
  String get label => switch (this) {
        AskPeriod.today => 'today',
        AskPeriod.last7Days => 'the last 7 days',
        AskPeriod.last14Days => 'the last 14 days',
        AskPeriod.last30Days => 'the last 30 days',
      };

  Duration get duration => switch (this) {
        AskPeriod.today => const Duration(days: 1),
        AskPeriod.last7Days => const Duration(days: 7),
        AskPeriod.last14Days => const Duration(days: 14),
        AskPeriod.last30Days => const Duration(days: 30),
      };
}

/// A classified question, or null topic when nothing matched.
typedef AskQuestion = ({AskTopic? topic, AskPeriod period});

/// One computed fact, with the id the model must cite to use it.
class DataFact {
  const DataFact({
    required this.id,
    required this.label,
    required this.value,
    this.unit = '',
  });

  /// Short stable handle, e.g. `tir`. What a citation refers to.
  final String id;

  /// Human-readable description of what the number is.
  final String label;

  /// The number itself, already rounded for display.
  final double value;
  final String unit;

  String get display =>
      '$label: ${_trim(value)}${unit.isEmpty ? '' : ' $unit'}';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// Classifies a plain-English question into the fixed taxonomy.
///
/// Keyword matching rather than a model: choosing WHICH facts to look at must not
/// depend on an optional download, and a wrong topic is a much cheaper failure when
/// it's a deterministic rule the user can learn.
AskQuestion classifyQuestion(String question) {
  final q = question.toLowerCase();

  final period = switch (q) {
    _ when q.contains('today') || q.contains('so far') => AskPeriod.today,
    _ when q.contains('30 day') || q.contains('month') => AskPeriod.last30Days,
    _ when q.contains('14 day') || q.contains('fortnight') =>
      AskPeriod.last14Days,
    _ => AskPeriod.last7Days,
  };

  // Order matters, most specific first. "am I low overnight" is an overnight
  // question and "how is my hypo risk" is a risk question — in both cases the
  // broader `lows` rule would match too and answer something subtly different from
  // what was asked.
  final topic = switch (q) {
    _ when _any(q, ['overnight', 'at night', 'while asleep', 'nocturnal']) =>
      AskTopic.overnight,
    _ when _any(q, ['risk', 'lbgi', 'hbgi']) => AskTopic.riskIndices,
    _ when _any(q, ['in range', 'tir', 'time in range']) => AskTopic.timeInRange,
    _ when _any(q, ['average', 'mean', 'typical glucose', 'a1c', 'gmi']) =>
      AskTopic.averageGlucose,
    _ when _any(q, ['low', 'hypo', 'below']) => AskTopic.lows,
    _ when _any(q, ['high', 'hyper', 'above', 'spike']) => AskTopic.highs,
    _ when _any(q, ['variability', 'variable', 'steady', 'stable', 'swing', 'sd']) =>
      AskTopic.variability,
    _ when _any(q, ['data', 'coverage', 'readings', 'sensor uptime']) =>
      AskTopic.dataCoverage,
    _ => null,
  };

  return (topic: topic, period: period);
}

/// Turns computed metrics into the fact sheet a question can draw on (AC#1).
List<DataFact> factsFrom(GlucoseMetrics m) => [
      DataFact(
          id: 'tir',
          label: 'Time in range (70–180)',
          value: _pct(m.timeInRange),
          unit: '%'),
      DataFact(
          id: 'tightRange',
          label: 'Time in tight range (70–140)',
          value: _pct(m.timeInTightRange),
          unit: '%'),
      DataFact(
          id: 'below70',
          label: 'Time below 70',
          value: _pct(m.timeBelow70),
          unit: '%'),
      DataFact(
          id: 'below54',
          label: 'Time below 54',
          value: _pct(m.timeBelow54),
          unit: '%'),
      DataFact(
          id: 'above180',
          label: 'Time above 180',
          value: _pct(m.timeAbove180),
          unit: '%'),
      DataFact(
          id: 'above250',
          label: 'Time above 250',
          value: _pct(m.timeAbove250),
          unit: '%'),
      DataFact(
          id: 'mean',
          label: 'Average glucose',
          value: _round1(m.meanMgdl),
          unit: 'mg/dL'),
      DataFact(
          id: 'sd',
          label: 'Standard deviation',
          value: _round1(m.sdMgdl),
          unit: 'mg/dL'),
      DataFact(id: 'lbgi', label: 'Low BG index', value: _round1(m.lbgi)),
      DataFact(id: 'hbgi', label: 'High BG index', value: _round1(m.hbgi)),
      DataFact(
          id: 'readings',
          label: 'Readings used',
          value: m.readingCount.toDouble()),
    ];

/// The facts relevant to [topic] (AC#1 retrieval).
///
/// Each topic pulls the neighbouring facts too, not just the single headline number: a
/// time-in-range answer that can't mention what the out-of-range time was spent doing
/// is not much of an answer.
List<DataFact> selectFacts(AskTopic topic, List<DataFact> all) {
  const byTopic = <AskTopic, List<String>>{
    AskTopic.timeInRange: ['tir', 'tightRange', 'below70', 'above180'],
    AskTopic.averageGlucose: ['mean', 'sd', 'tir'],
    AskTopic.lows: ['below70', 'below54', 'lbgi'],
    AskTopic.highs: ['above180', 'above250', 'hbgi'],
    AskTopic.variability: ['sd', 'mean', 'tir'],
    AskTopic.overnight: ['below70', 'tir', 'mean'],
    AskTopic.riskIndices: ['lbgi', 'hbgi', 'below70', 'above180'],
    AskTopic.dataCoverage: ['readings'],
  };
  final wanted = byTopic[topic] ?? const <String>[];
  // Ordered by the topic's list, not the sheet's, so the headline fact leads.
  return [
    for (final id in wanted)
      ...all.where((f) => f.id == id),
  ];
}

/// The prompt: facts in, phrasing out, citations required.
String buildAskPrompt(String question, List<DataFact> facts, AskPeriod period) {
  final sheet = facts.map((f) => '- [${f.id}] ${f.display}').join('\n');
  return '''
Answer the user's question using ONLY the facts listed below. These are measurements from
their own data over ${period.label}.

Rules:
- Never state a number that is not in the facts. Do not calculate new numbers.
- After each statement, cite the fact that backs it in square brackets, e.g. [tir].
- If the facts do not answer the question, say so plainly. Do not guess.
- Two or three sentences. No preamble.

Facts:
$sheet

Question: $question
''';
}

/// Why an answer was rejected.
enum AskRejection {
  /// A number appears that isn't in any cited fact.
  uncitedNumber,

  /// No citation at all.
  noCitation,

  /// Cites a fact id that wasn't offered.
  unknownFact,
}

/// The result of checking a model's answer against the facts it was given (AC#2).
typedef AskCheck = ({bool accepted, AskRejection? reason});

/// Rejects an answer that isn't fully backed by [facts].
///
/// Numbers are checked against the *cited* facts rather than the whole sheet, so a model
/// cannot borrow an unrelated fact's number to make an unrelated claim look sourced.
///
/// Years and small counts embedded in words are not what this guards; the risk is a
/// fabricated *measurement*, so any number appearing in the text must be traceable to a
/// cited fact.
AskCheck checkAnswer(String answer, List<DataFact> facts) {
  final citations = RegExp(r'\[([A-Za-z0-9_]+)\]')
      .allMatches(answer)
      .map((m) => m.group(1)!)
      .toList();
  if (citations.isEmpty) {
    // An answer with no numbers and no citation is still unusable: we cannot tell
    // whether it came from the data or from the model's imagination.
    return (accepted: false, reason: AskRejection.noCitation);
  }

  final known = {for (final f in facts) f.id: f};
  for (final c in citations) {
    if (!known.containsKey(c)) {
      return (accepted: false, reason: AskRejection.unknownFact);
    }
  }

  final citedValues = [for (final c in citations) known[c]!.value];
  // Strip the citation markers before scanning, or an id like `below70` would supply
  // its own "70" and validate itself.
  final prose = answer.replaceAll(RegExp(r'\[[A-Za-z0-9_]+\]'), ' ');
  for (final match in RegExp(r'\d+(?:\.\d+)?\s*%?').allMatches(prose)) {
    final token = match.group(0)!.trim();
    final isPercentage = token.endsWith('%');
    final n = double.tryParse(token.replaceAll('%', '').trim());
    if (n == null) continue;
    final backed = citedValues.any((v) => (v - n).abs() < 0.5) ||
        // Threshold names ("below 70", "above 180") are the vocabulary for saying
        // WHICH band is meant, not claims about the data — but only when written as
        // a bare number. "70%" is always a measurement, and exempting it would let
        // the threshold list launder fabricated percentages.
        (!isPercentage && _thresholdVocabulary.contains(n));
    if (!backed) return (accepted: false, reason: AskRejection.uncitedNumber);
  }

  return (accepted: true, reason: null);
}

/// Glucose thresholds the answer may name without them counting as measurements.
final Set<double> _thresholdVocabulary = <double>{54, 70, 140, 180, 250};

bool _any(String haystack, List<String> needles) =>
    needles.any(haystack.contains);

double _pct(double fraction) => _round1(fraction * 100);

double _round1(double v) => (v * 10).roundToDouble() / 10;
