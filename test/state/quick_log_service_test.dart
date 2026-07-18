/// The illness severity→boost mapping and mood note strings are domain
/// policy — pinned here so a widget refactor can't silently change a clinical
/// multiplier.
library;

import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/state/quick_log_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('illness severity maps to the expected resistance boosts', () {
    expect(IllnessSeverity.mild.resistanceBoost, 1.1);
    expect(IllnessSeverity.moderate.resistanceBoost, 1.2);
    expect(IllnessSeverity.severe.resistanceBoost, 1.35);
  });

  test('boosts are monotonic in severity and stay conservative', () {
    final boosts = [
      for (final s in IllnessSeverity.values) s.resistanceBoost,
    ];
    for (var i = 1; i < boosts.length; i++) {
      expect(boosts[i], greaterThan(boosts[i - 1]));
    }
    expect(boosts.first, greaterThan(1.0));
    expect(boosts.last, lessThanOrEqualTo(1.5));
  });

  test('mood notes keep the pre-extraction strings (annotation compatibility)', () {
    expect(MoodLevel.good.note, 'Good');
    expect(MoodLevel.ok.note, 'OK');
    expect(MoodLevel.low.note, 'Low');
  });

  test('every severity and mood has a distinct, non-empty picker label', () {
    // The sheet renders these directly; a duplicated or blank label is an
    // unpickable option, and the note strings above must NOT be reused as labels
    // (the mood labels carry an emoji, the notes must stay bare for matching).
    final severityLabels = [
      for (final s in IllnessSeverity.values) s.label,
    ];
    expect(severityLabels, ['Mild', 'Moderate', 'Severe']);
    expect(severityLabels.toSet(), hasLength(IllnessSeverity.values.length));

    final moodLabels = [for (final m in MoodLevel.values) m.label];
    expect(moodLabels.toSet(), hasLength(MoodLevel.values.length));
    for (final m in MoodLevel.values) {
      expect(m.label, contains(m.note));
      expect(m.label, isNot(m.note),
          reason: 'the label decorates the note; if they converge the emoji '
              'has been lost from the picker');
    }
  });

  group('QuickLogService orchestration', () {
    ProviderContainer containerWith(HistoryRepository repo) {
      final c = ProviderContainer(overrides: [
        historyRepositoryProvider.overrideWithValue(repo),
        notificationServiceProvider.overrideWithValue(NotificationService()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    // activate()/deactivate() are void but publish their new state only once the
    // unawaited _persist() write completes, so every assertion below has to let
    // the event queue drain first — reading synchronously sees the stale state.
    test('startIllness activates illness mode at the severity\'s boost',
        () async {
      final container = containerWith(InMemoryHistoryRepository());
      final service = container.read(quickLogServiceProvider);

      expect(container.read(illnessModeProvider).active, isFalse);

      service.startIllness(IllnessSeverity.severe);
      await pumpEventQueue();

      final mode = container.read(illnessModeProvider);
      expect(mode.active, isTrue);
      // The whole point of the severity tiers: the picked one must reach the
      // model, not a hard-coded default boost.
      expect(
          mode.expectedResistanceBoost, IllnessSeverity.severe.resistanceBoost);
    });

    test('endIllness deactivates a mode that startIllness turned on', () async {
      final container = containerWith(InMemoryHistoryRepository());
      final service = container.read(quickLogServiceProvider);

      service.startIllness(IllnessSeverity.mild);
      await pumpEventQueue();
      expect(container.read(illnessModeProvider).active, isTrue);

      service.endIllness();
      await pumpEventQueue();
      expect(container.read(illnessModeProvider).active, isFalse);
    });

    test('logMood persists a mood annotation carrying the level\'s note',
        () async {
      final repo = InMemoryHistoryRepository();
      final service = containerWith(repo).read(quickLogServiceProvider);

      await service.logMood(MoodLevel.low);

      final now = DateTime.now(); // now-ok: logContext stamps the annotation from the wall clock
      final saved = await repo.annotations(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );
      final mood = saved.where((a) => a.kind == AnnotationKind.mood);
      expect(mood, hasLength(1));
      // The note is what the correlation reports group on — a mislabelled or
      // empty note silently drops the entry out of every mood correlation.
      expect(mood.single.note, MoodLevel.low.note);
    });
  });
}
