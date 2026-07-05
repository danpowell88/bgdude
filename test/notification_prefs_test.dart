import 'dart:convert';

import 'package:bgdude/insights/notification_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPrefs', () {
    test('defaults() has an entry for every category', () {
      final prefs = NotificationPrefs.defaults();
      for (final c in NotificationCategory.values) {
        expect(prefs.byCategory.containsKey(c), isTrue, reason: c.name);
      }
    });

    test('every default repeat interval is a standard dropdown option', () {
      // The Notifications screen's "Repeat until clear" dropdown offers this set; a
      // default outside it used to crash the DropdownButton (assert on unmatched value).
      const options = {0, 5, 15, 30, 60};
      final prefs = NotificationPrefs.defaults();
      for (final c in NotificationCategory.values) {
        expect(options.contains(prefs.of(c).repeatMinutes), isTrue,
            reason: '${c.name} repeats every ${prefs.of(c).repeatMinutes}m');
      }
    });

    test('urgent low is the loudest default and repeats', () {
      final p = NotificationPrefs.defaults().of(NotificationCategory.urgentLow);
      expect(p.enabled, isTrue);
      expect(p.importance, NotifImportance.urgent);
      expect(p.repeatMinutes, greaterThan(0));
    });

    test('quiet categories are silent-ish and one-shot by default', () {
      final p =
          NotificationPrefs.defaults().of(NotificationCategory.deviceReminder);
      expect(p.repeatMinutes, 0);
      expect(p.sound, isFalse);
    });

    test('JSON round-trips through the encrypted-store encoding', () {
      final original = NotificationPrefs.defaults()
          .withCategory(
            NotificationCategory.predictedHigh,
            const CategoryPref(
              enabled: false,
              importance: NotifImportance.silent,
              vibrate: false,
              sound: false,
              repeatMinutes: 5,
            ),
          )
          .withCategory(
            NotificationCategory.urgentLow,
            NotificationPrefs.defaults()
                .of(NotificationCategory.urgentLow)
                .copyWith(repeatMinutes: 10),
          );

      final restored = NotificationPrefs.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      for (final c in NotificationCategory.values) {
        final a = original.of(c);
        final b = restored.of(c);
        expect(b.enabled, a.enabled, reason: c.name);
        expect(b.importance, a.importance, reason: c.name);
        expect(b.vibrate, a.vibrate, reason: c.name);
        expect(b.sound, a.sound, reason: c.name);
        expect(b.repeatMinutes, a.repeatMinutes, reason: c.name);
      }
    });

    test('partial/legacy JSON falls back to per-category defaults', () {
      final restored = NotificationPrefs.fromJson({
        'urgentLow': {'enabled': false},
      });
      // The provided category keeps its stored flag...
      expect(restored.of(NotificationCategory.urgentLow).enabled, isFalse);
      // ...missing importance falls back sanely, and absent categories default.
      expect(restored.of(NotificationCategory.predictedLow).enabled, isTrue);
      expect(restored.of(NotificationCategory.predictedLow).importance,
          NotifImportance.high);
    });

    test('copyWith changes only the named field', () {
      const base = CategoryPref(
        enabled: true,
        importance: NotifImportance.normal,
        vibrate: true,
        sound: true,
        repeatMinutes: 0,
      );
      final next = base.copyWith(repeatMinutes: 15);
      expect(next.repeatMinutes, 15);
      expect(next.enabled, base.enabled);
      expect(next.importance, base.importance);
      expect(next.vibrate, base.vibrate);
      expect(next.sound, base.sound);
    });

    test('every category exposes a label and description', () {
      for (final c in NotificationCategory.values) {
        expect(c.label, isNotEmpty, reason: c.name);
        expect(c.description, isNotEmpty, reason: c.name);
      }
    });
  });
}
