/// Answering a typed question about your own data (issue #80).
///
/// Orchestration only — the taxonomy, retrieval and citation rule live in
/// `ask_data.dart`. The model is optional: without one, the retrieved facts are listed
/// directly, which is less conversational but exactly as true.
library;

import '../analytics/metrics.dart';
import '../logging/app_log.dart';
import 'ask_data.dart';

/// The phrasing step, behind an interface so the service is testable without a model.
abstract interface class AskPhraser {
  bool get available;

  /// Phrase [prompt] into an answer, or null when it can't.
  Future<String?> phrase(String prompt);
}

class NoopAskPhraser implements AskPhraser {
  const NoopAskPhraser();
  @override
  bool get available => false;
  @override
  Future<String?> phrase(String prompt) async => null;
}

/// Why an answer looks the way it does — surfaced to the user, because "the model
/// wasn't trusted" and "there's no model installed" deserve different wording.
enum AskAnswerKind {
  /// Phrased by the model and accepted by the citation check.
  phrased,

  /// The facts, listed plainly (no model, or the model's answer was rejected).
  facts,

  /// The question isn't one this feature answers.
  notUnderstood,

  /// There isn't enough data to answer.
  noData,
}

class AskAnswer {
  const AskAnswer({
    required this.kind,
    required this.text,
    this.facts = const [],
    this.rejection,
  });

  final AskAnswerKind kind;
  final String text;

  /// The facts behind the answer — always shown, so every number is checkable.
  final List<DataFact> facts;

  /// Set when a model answer was thrown out, for the log and for honesty in the UI.
  final AskRejection? rejection;
}

class AskDataService {
  AskDataService({required this.phraser});

  final AskPhraser phraser;

  /// Answers [question] from [metrics], which the caller computes for the period the
  /// question asked about.
  Future<AskAnswer> answer(String question, GlucoseMetrics? metrics) async {
    final parsed = classifyQuestion(question);
    if (parsed.topic == null) {
      return const AskAnswer(
        kind: AskAnswerKind.notUnderstood,
        text: "I can answer questions about your time in range, average glucose, "
            "lows, highs, variability, overnight pattern, risk indices and data "
            "coverage. I couldn't tell which of those you meant.",
      );
    }
    if (metrics == null || metrics.readingCount == 0) {
      return const AskAnswer(
        kind: AskAnswerKind.noData,
        text: "There aren't enough readings in that period to answer.",
      );
    }

    final facts = selectFacts(parsed.topic!, factsFrom(metrics));
    if (facts.isEmpty) {
      return AskAnswer(
        kind: AskAnswerKind.noData,
        text: "I don't have the numbers for that.",
        facts: facts,
      );
    }

    if (phraser.available) {
      try {
        final raw = await phraser
            .phrase(buildAskPrompt(question, facts, parsed.period));
        if (raw != null && raw.trim().isNotEmpty) {
          final check = checkAnswer(raw, facts);
          if (check.accepted) {
            return AskAnswer(
              kind: AskAnswerKind.phrased,
              text: raw.trim(),
              facts: facts,
            );
          }
          // Rejected, not repaired. An answer that failed the citation rule is not
          // salvageable by editing — the model has already shown it will state
          // things the data doesn't support, so fall back to the data itself.
          appLog.info('ask_data',
              'model answer rejected: ${check.reason?.name}');
          return AskAnswer(
            kind: AskAnswerKind.facts,
            text: _plainFacts(facts, parsed.period),
            facts: facts,
            rejection: check.reason,
          );
        }
      } catch (e) {
        appLog.error('ask_data', 'phrasing failed', error: e);
      }
    }

    return AskAnswer(
      kind: AskAnswerKind.facts,
      text: _plainFacts(facts, parsed.period),
      facts: facts,
    );
  }

  /// The facts, stated plainly. Not a fallback in the apologetic sense — these are the
  /// same numbers the phrased answer would have been built from.
  String _plainFacts(List<DataFact> facts, AskPeriod period) =>
      'Over ${period.label}:\n${facts.map((f) => '• ${f.display}').join('\n')}';
}
