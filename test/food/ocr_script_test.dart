/// Detecting a label the Latin-only recognizer cannot read (issue #103).
library;

import 'package:bgdude/food/ocr_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectUnsupportedScript', () {
    test('an ordinary English panel is readable', () {
      expect(
        detectUnsupportedScript(
            'Nutrition Information\nEnergy 550kJ\nProtein 4.0g\nCarbohydrate 12g'),
        isNull,
      );
    });

    test('a Japanese panel is flagged', () {
      expect(detectUnsupportedScript('栄養成分表示 エネルギー 550kJ たんぱく質 4.0g'),
          UnsupportedScript.chineseJapaneseKorean);
    });

    test('Chinese and Korean are flagged as the same family', () {
      // One recognizer covers all three, so one message covers all three.
      expect(detectUnsupportedScript('营养成分表 能量 550千焦 蛋白质'),
          UnsupportedScript.chineseJapaneseKorean);
      expect(detectUnsupportedScript('영양성분 열량 에너지 단백질'),
          UnsupportedScript.chineseJapaneseKorean);
    });

    test('Cyrillic, Thai, Arabic and Devanagari are each named', () {
      expect(detectUnsupportedScript('Пищевая ценность Белки Жиры Углеводы'),
          UnsupportedScript.cyrillic);
      expect(detectUnsupportedScript('ข้อมูลโภชนาการ พลังงาน โปรตีน'),
          UnsupportedScript.thai);
      expect(detectUnsupportedScript('القيمة الغذائية الطاقة البروتين'),
          UnsupportedScript.arabic);
      expect(detectUnsupportedScript('पोषण संबंधी जानकारी ऊर्जा प्रोटीन'),
          UnsupportedScript.devanagari);
    });

    test('a stray non-Latin character does NOT flag an English label', () {
      // Firing on a ° or a brand mark would tell people their English label is
      // unsupported — worse than the silence this replaces.
      expect(
        detectUnsupportedScript(
            'Nutrition Information 20°C\nEnergy 550kJ\nProtein 4.0g '
            'Brand™ 株式会社'),
        isNull,
      );
    });

    test('digits and punctuation do not dilute the signal', () {
      // A nutrition panel is mostly numbers; counting them as "Latin" would push a
      // genuinely Japanese panel below the threshold.
      expect(
        detectUnsupportedScript('エネルギー 550 kJ / 100 g (12.5%) たんぱく質 4.0'),
        UnsupportedScript.chineseJapaneseKorean,
      );
    });

    test('empty or blank text is not blamed on the script', () {
      // Nothing recognised is a different problem — a dark photo, a missed panel.
      expect(detectUnsupportedScript(''), isNull);
      expect(detectUnsupportedScript('   \n  '), isNull);
      expect(detectUnsupportedScript('123 456'), isNull);
    });

    test('the dominant script wins when two are present', () {
      final mostlyJapanese =
          detectUnsupportedScript('栄養成分表示 エネルギー たんぱく質 脂質 炭水化物 Привет');
      expect(mostlyJapanese, UnsupportedScript.chineseJapaneseKorean);
    });
  });

  group('unsupportedScriptMessage', () {
    test('names the script and does not suggest retaking the photo', () {
      // The failure this fixes is people re-photographing a label that will never
      // read, because the app implied the photo was the problem.
      final message =
          unsupportedScriptMessage(UnsupportedScript.chineseJapaneseKorean);

      expect(message, contains('Chinese, Japanese or Korean'));
      expect(message, contains('will not help'));
      expect(message, contains('by hand'));
    });

    test('every script has a usable message', () {
      for (final s in UnsupportedScript.values) {
        expect(unsupportedScriptMessage(s), contains(s.label), reason: s.name);
      }
    });
  });
}
