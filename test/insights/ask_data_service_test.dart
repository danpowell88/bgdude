/// Ask-your-data orchestration (issue #80).
library;

import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/insights/ask_data.dart';
import 'package:bgdude/insights/ask_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePhraser implements AskPhraser {
  _FakePhraser({this.available = true, this.response, this.throws = false});

  @override
  final bool available;
  final String? response;
  final bool throws;
  int calls = 0;
  String? lastPrompt;

  @override
  Future<String?> phrase(String prompt) async {
    calls++;
    lastPrompt = prompt;
    if (throws) throw Exception('model OOM');
    return response;
  }
}

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

const _empty = GlucoseMetrics(
  readingCount: 0,
  meanMgdl: 0,
  sdMgdl: 0,
  timeInRange: 0,
  timeInTightRange: 0,
  timeBelow70: 0,
  timeBelow54: 0,
  timeAbove180: 0,
  timeAbove250: 0,
  coveragePeriod: Duration(days: 7),
  expectedReadings: 2016,
  sufficient: false,
);

void main() {
  test('a properly cited model answer is used', () async {
    final service = AskDataService(
      phraser: _FakePhraser(
        response: 'You were in range 72.4% of the time [tir].',
      ),
    );

    final answer = await service.answer('how much time in range?', _metrics);

    expect(answer.kind, AskAnswerKind.phrased);
    expect(answer.text, contains('72.4'));
    // The facts come back regardless, so every number stays checkable.
    expect(answer.facts, isNotEmpty);
  });

  test('an answer with an invented number is REJECTED, not shown', () async {
    // The safety property: a fabricated measurement never reaches the user, even
    // wrapped in an otherwise-correct sentence.
    final service = AskDataService(
      phraser: _FakePhraser(
        response: 'In range 72.4% [tir], and your average was 118 mg/dL [tir].',
      ),
    );

    final answer = await service.answer('how much time in range?', _metrics);

    expect(answer.kind, AskAnswerKind.facts);
    expect(answer.rejection, AskRejection.uncitedNumber);
    expect(answer.text, isNot(contains('118')));
    // Falls back to the real numbers rather than to nothing.
    expect(answer.text, contains('72.4'));
  });

  test('an uncited answer is rejected', () async {
    final service = AskDataService(
      phraser: _FakePhraser(response: 'You are doing well.'),
    );

    final answer = await service.answer('how much time in range?', _metrics);

    expect(answer.kind, AskAnswerKind.facts);
    expect(answer.rejection, AskRejection.noCitation);
  });

  test('with no model, the facts are stated plainly', () async {
    final phraser = _FakePhraser(available: false);
    final service = AskDataService(phraser: phraser);

    final answer = await service.answer('how much time in range?', _metrics);

    expect(phraser.calls, 0);
    expect(answer.kind, AskAnswerKind.facts);
    expect(answer.text, contains('72.4'));
    expect(answer.text, contains('the last 7 days'));
  });

  test('a model that throws degrades to the facts', () async {
    final service = AskDataService(phraser: _FakePhraser(throws: true));

    final answer = await service.answer('how much time in range?', _metrics);

    expect(answer.kind, AskAnswerKind.facts);
    expect(answer.text, contains('72.4'));
  });

  test('an unrecognised question is declined, not guessed at', () async {
    final phraser = _FakePhraser();
    final service = AskDataService(phraser: phraser);

    final answer = await service.answer('what should I eat tonight?', _metrics);

    expect(answer.kind, AskAnswerKind.notUnderstood);
    // Never even reaches the model — there are no facts that would answer it, so a
    // phrased reply could only be invented.
    expect(phraser.calls, 0);
    // Says what it CAN answer, rather than just refusing.
    expect(answer.text, contains('time in range'));
  });

  test('no readings means "not enough data", not a zero answer', () async {
    final service = AskDataService(phraser: _FakePhraser());

    expect((await service.answer('time in range?', _empty)).kind,
        AskAnswerKind.noData);
    expect((await service.answer('time in range?', null)).kind,
        AskAnswerKind.noData);
  });

  test('the prompt carries the retrieved facts and the period', () async {
    final phraser = _FakePhraser(response: 'In range 72.4% [tir].');
    final service = AskDataService(phraser: phraser);

    await service.answer('how much time in range this month?', _metrics);

    expect(phraser.lastPrompt, contains('[tir]'));
    expect(phraser.lastPrompt, contains('the last 30 days'));
  });
}
