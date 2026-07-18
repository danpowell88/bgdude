/// Ask-your-data Q&A: taxonomy, retrieval and the citation rule (issue #80).
library;

import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/insights/ask_data.dart';
import 'package:flutter_test/flutter_test.dart';

const _metrics = GlucoseMetrics(
  readingCount: 1980,
  meanMgdl: 142.3,
  sdMgdl: 38.7,
  timeInRange: 0.724,
  timeInTightRange: 0.501,
  timeBelow70: 0.031,
  timeBelow54: 0.004,
  timeAbove180: 0.245,
  timeAbove250: 0.052,
  coveragePeriod: Duration(days: 7),
  expectedReadings: 2016,
  sufficient: true,
  lbgi: 1.8,
  hbgi: 6.2,
);

void main() {
  group('classifyQuestion', () {
    test('maps everyday phrasings onto the taxonomy', () {
      expect(classifyQuestion('how much time am I in range?').topic,
          AskTopic.timeInRange);
      expect(classifyQuestion("what's my average glucose").topic,
          AskTopic.averageGlucose);
      expect(classifyQuestion('am I going low a lot').topic, AskTopic.lows);
      expect(classifyQuestion('how often do I spike').topic, AskTopic.highs);
      expect(classifyQuestion('how steady have I been').topic,
          AskTopic.variability);
      expect(classifyQuestion('how is my hypo risk').topic,
          AskTopic.riskIndices);
    });

    test('overnight beats lows when a question mentions both', () {
      // "am I low overnight" is an overnight question; checking lows first would
      // silently answer a different question than the one asked.
      expect(classifyQuestion('am I going low overnight?').topic,
          AskTopic.overnight);
    });

    test('an unrecognised question has no topic rather than a guessed one', () {
      // Declining is the point of a closed taxonomy: a guessed topic produces a
      // confident answer to a question nobody asked.
      expect(classifyQuestion('what should I have for dinner?').topic, isNull);
      expect(classifyQuestion('').topic, isNull);
    });

    test('reads the period, defaulting to a week', () {
      expect(classifyQuestion('how am I doing today').period, AskPeriod.today);
      expect(classifyQuestion('time in range this month').period,
          AskPeriod.last30Days);
      expect(classifyQuestion('time in range over 14 days').period,
          AskPeriod.last14Days);
      expect(classifyQuestion('how much time in range').period,
          AskPeriod.last7Days);
    });
  });

  group('factsFrom', () {
    test('converts fractions to percentages', () {
      final facts = factsFrom(_metrics);
      final tir = facts.firstWhere((f) => f.id == 'tir');

      expect(tir.value, closeTo(72.4, 0.001));
      expect(tir.unit, '%');
      expect(tir.display, contains('72.4 %'));
    });

    test('every fact has a unique id the model can cite', () {
      final ids = factsFrom(_metrics).map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('whole numbers display without a trailing decimal', () {
      final readings = factsFrom(_metrics).firstWhere((f) => f.id == 'readings');
      expect(readings.display, contains('1980'));
      expect(readings.display, isNot(contains('1980.0')));
    });
  });

  group('selectFacts', () {
    test('a lows question retrieves the low facts and the risk index', () {
      final selected = selectFacts(AskTopic.lows, factsFrom(_metrics));

      expect(selected.map((f) => f.id), ['below70', 'below54', 'lbgi']);
    });

    test('the headline fact leads', () {
      // Ordered by the topic, not by the sheet, so the model sees the most
      // relevant number first.
      expect(selectFacts(AskTopic.timeInRange, factsFrom(_metrics)).first.id,
          'tir');
    });

    test('every topic retrieves something', () {
      // A topic with no facts would produce an answer with nothing to cite, which
      // the citation check then rejects — a dead end the user can't act on.
      for (final topic in AskTopic.values) {
        expect(selectFacts(topic, factsFrom(_metrics)), isNotEmpty,
            reason: topic.name);
      }
    });
  });

  group('buildAskPrompt', () {
    test('lists the facts with their citation ids and forbids new numbers', () {
      final prompt = buildAskPrompt(
        'how much time in range?',
        selectFacts(AskTopic.timeInRange, factsFrom(_metrics)),
        AskPeriod.last7Days,
      );

      expect(prompt, contains('[tir]'));
      expect(prompt, contains('72.4'));
      expect(prompt, contains('Never state a number that is not in the facts'));
      expect(prompt, contains('the last 7 days'));
    });
  });

  group('checkAnswer — the rule that makes this safe', () {
    final facts = selectFacts(AskTopic.timeInRange, factsFrom(_metrics));

    test('accepts an answer whose numbers all come from cited facts', () {
      const answer =
          'You were in range 72.4% of the time [tir], with 24.5% above 180 '
          '[above180].';

      expect(checkAnswer(answer, facts).accepted, isTrue);
    });

    test('REJECTS a number that appears in no cited fact', () {
      // The failure this whole design exists to prevent: a plausible, confidently
      // worded, invented measurement sitting next to insulin dosing.
      const answer = 'You were in range 72.4% of the time [tir], and your '
          'average was 118 mg/dL [tir].';

      final check = checkAnswer(answer, facts);
      expect(check.accepted, isFalse);
      expect(check.reason, AskRejection.uncitedNumber);
    });

    test('REJECTS a number borrowed from an uncited fact', () {
      // 38.7 is a real fact (sd) but was not cited here, so it is not backing
      // anything — the model cannot launder a number by proximity.
      const answer = 'Your variability was 38.7 [tir].';

      expect(checkAnswer(answer, facts).reason, AskRejection.uncitedNumber);
    });

    test('REJECTS an answer with no citation at all', () {
      const answer = 'You are doing pretty well overall.';

      expect(checkAnswer(answer, facts).reason, AskRejection.noCitation);
    });

    test('REJECTS a citation to a fact that was never offered', () {
      const answer = 'Your kidney function is fine [kidneys].';

      expect(checkAnswer(answer, facts).reason, AskRejection.unknownFact);
    });

    test('a citation id containing digits cannot validate itself', () {
      // `[below70]` must not supply the "70" that backs a claim of 70 — otherwise
      // the check is trivially defeated by the fact ids themselves.
      const answer = 'You spent 70% of the time below range [below70].';

      expect(checkAnswer(answer, facts).accepted, isFalse);
    });

    test('naming a threshold is vocabulary, not a measurement', () {
      // "below 70" describes which band is meant; it is not a claim about the data.
      const answer =
          'You were below 70 for 3.1% of the time [below70], and in range '
          '72.4% [tir].';

      expect(checkAnswer(answer, facts).accepted, isTrue);
    });

    test('small rounding differences are tolerated', () {
      // 72.4 quoted as 72 is the same fact, not a fabrication.
      const answer = 'Roughly 72% in range [tir].';

      expect(checkAnswer(answer, facts).accepted, isTrue);
    });

    test('a prose-only answer that cites a fact is accepted', () {
      const answer = 'Your time in range is on the better side of typical [tir].';

      expect(checkAnswer(answer, facts).accepted, isTrue);
    });
  });
}
