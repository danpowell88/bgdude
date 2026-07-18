/// The ask-your-data answer view (issue #80).
library;

import 'package:bgdude/insights/ask_data.dart';
import 'package:bgdude/insights/ask_data_service.dart';
import 'package:bgdude/ui/widgets/ask_answer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _facts = [
  DataFact(id: 'tir', label: 'Time in range (70–180)', value: 72.4, unit: '%'),
  DataFact(id: 'below70', label: 'Time below 70', value: 3.1, unit: '%'),
];

Future<void> _pump(WidgetTester tester, AskAnswer answer) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: AskAnswerView(answer: answer)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the answer and the facts behind it', (tester) async {
    // The facts are the point: an answer nobody can check is just a claim.
    await _pump(
      tester,
      const AskAnswer(
        kind: AskAnswerKind.phrased,
        text: 'You were in range 72.4% of the time.',
        facts: _facts,
      ),
    );

    expect(find.textContaining('in range 72.4%'), findsOneWidget);
    expect(find.text('Based on'), findsOneWidget);
    expect(find.textContaining('Time below 70: 3.1 %'), findsOneWidget);
    expect(find.textContaining('nothing here is estimated or generated'),
        findsOneWidget);
  });

  testWidgets('says plainly when the AI answer was thrown out', (tester) async {
    // Silently swapping to a different kind of answer would leave the user
    // wondering why today's reply reads differently from yesterday's.
    await _pump(
      tester,
      const AskAnswer(
        kind: AskAnswerKind.facts,
        text: 'Over the last 7 days:\n• Time in range (70–180): 72.4 %',
        facts: _facts,
        rejection: AskRejection.uncitedNumber,
      ),
    );

    expect(find.textContaining("didn't match your data"), findsOneWidget);
  });

  testWidgets('an accepted answer carries no rejection note', (tester) async {
    await _pump(
      tester,
      const AskAnswer(
        kind: AskAnswerKind.phrased,
        text: 'Mostly in range.',
        facts: _facts,
      ),
    );

    expect(find.textContaining("didn't match your data"), findsNothing);
  });

  testWidgets('a not-understood answer shows no "Based on" section',
      (tester) async {
    // There are no facts behind it, and an empty section would imply there were.
    await _pump(
      tester,
      const AskAnswer(
        kind: AskAnswerKind.notUnderstood,
        text: "I couldn't tell which of those you meant.",
      ),
    );

    expect(find.text('Based on'), findsNothing);
    expect(find.textContaining("couldn't tell"), findsOneWidget);
  });
}
