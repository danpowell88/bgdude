/// Ask a question about your own data (issue #80).
///
/// The answer's facts are always shown beneath it, so every number is checkable against
/// what the app actually measured — the point of the feature is that nothing here is
/// invented, and that only helps if you can see the working.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../insights/ask_data.dart';
import '../insights/ask_data_service.dart';
import '../state/providers.dart';
import 'widgets/ask_answer_view.dart';

/// The questions this feature is built to answer — shown as chips, because a closed
/// taxonomy is only usable if you can see what's in it.
const List<String> askSuggestions = [
  'How much time am I in range?',
  "What's my average glucose?",
  'Am I going low overnight?',
  'How often do I go high?',
  'How steady have I been?',
  'How is my hypo risk?',
];

class AskDataScreen extends ConsumerStatefulWidget {
  const AskDataScreen({super.key});

  @override
  ConsumerState<AskDataScreen> createState() => _AskDataScreenState();
}

class _AskDataScreenState extends ConsumerState<AskDataScreen> {
  final _controller = TextEditingController();
  AskAnswer? _answer;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    if (question.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _controller.text = question;
    });
    // Read metrics over the period the question itself asked about, so "this month"
    // isn't answered with today's numbers.
    final period = classifyQuestion(question).period;
    final metrics = await ref.read(askMetricsProvider(period).future);
    final answer = await ref.read(askDataServiceProvider).answer(question, metrics);
    if (!mounted) return;
    setState(() {
      _answer = answer;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask your data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('ask-field'),
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'How much time am I in range?',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const Key('ask-submit'),
                icon: const Icon(Icons.send),
                onPressed: _busy ? null : () => _ask(_controller.text),
              ),
            ),
            onSubmitted: _busy ? null : _ask,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in askSuggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: _busy ? null : () => _ask(s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (!_busy && answer != null) AskAnswerView(answer: answer),
        ],
      ),
    );
  }
}
