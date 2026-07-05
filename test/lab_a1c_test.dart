import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/lab_a1c.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlycationGap', () {
    test('flags a lab result that runs higher than GMI', () {
      const g = GlycationGap(labPercent: 7.6, gmiPercent: 6.8);
      expect(g.gapPercent, closeTo(0.8, 1e-9));
      expect(g.significant, isTrue);
      expect(g.message.toLowerCase(), contains('higher'));
    });

    test('flags a lab result that runs lower than GMI', () {
      const g = GlycationGap(labPercent: 6.2, gmiPercent: 7.0);
      expect(g.gapPercent, closeTo(-0.8, 1e-9));
      expect(g.significant, isTrue);
      expect(g.message.toLowerCase(), contains('lower'));
    });

    test('within 0.5% is not significant', () {
      const g = GlycationGap(labPercent: 6.9, gmiPercent: 6.7);
      expect(g.significant, isFalse);
      expect(g.message.toLowerCase(), contains('agree'));
    });
  });

  group('LabA1cStore', () {
    setUp(KvStore.useMemory);

    test('adds, sorts by date, and the latest is last', () async {
      await LabA1cStore.add(LabA1c(percent: 7.0, date: DateTime(2026, 1, 1)));
      await LabA1cStore.add(LabA1c(percent: 6.8, date: DateTime(2026, 4, 1)));
      await LabA1cStore.add(LabA1c(percent: 6.9, date: DateTime(2026, 2, 1)));
      final all = await LabA1cStore.load();
      expect(all, hasLength(3));
      expect(all.first.date, DateTime(2026, 1, 1));
      expect(all.last.percent, 6.8); // April, the most recent
    });

    test('round-trips through JSON', () async {
      final entry = LabA1c(percent: 7.2, date: DateTime(2026, 3, 15));
      final restored = LabA1c.fromJson(entry.toJson());
      expect(restored.percent, 7.2);
      expect(restored.date, DateTime(2026, 3, 15));
    });
  });
}
