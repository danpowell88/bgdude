/// Row reconstruction from OCR geometry (issue #104).
library;

import 'package:bgdude/food/panel_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A line 20px tall at [top], spanning [left]..[left]+width.
OcrLine _line(String text, double left, double top, {double width = 100}) =>
    OcrLine(
      text: text,
      left: left,
      top: top,
      right: left + width,
      bottom: top + 20,
    );

void main() {
  group('groupIntoRows', () {
    test('rebuilds rows when the recogniser emitted one block per column', () {
      // The failure this whole feature exists for: ML Kit returns all the labels,
      // then all the per-serve numbers, then all the per-100g numbers. Flattened,
      // "Carbohydrate" and its values are six lines apart.
      final lines = [
        _line('Carbohydrate', 10, 100),
        _line('Protein', 10, 140),
        _line('12.0g', 200, 100, width: 50),
        _line('4.0g', 200, 140, width: 50),
        _line('24.0g', 300, 100, width: 50),
        _line('8.0g', 300, 140, width: 50),
      ];

      expect(reconstructColumns(lines),
          'Carbohydrate  12.0g  24.0g\nProtein  4.0g  8.0g');
    });

    test('orders each row left-to-right regardless of input order', () {
      // Per-100g arriving before per-serve would silently swap the two columns.
      final lines = [
        _line('24.0g', 300, 100, width: 50),
        _line('12.0g', 200, 100, width: 50),
        _line('Carbohydrate', 10, 100),
      ];

      expect(reconstructColumns(lines), 'Carbohydrate  12.0g  24.0g');
    });

    test('rows come out top-to-bottom', () {
      final lines = [
        _line('Protein', 10, 200),
        _line('Energy', 10, 60),
        _line('Carbohydrate', 10, 130),
      ];

      expect(reconstructColumns(lines), 'Energy\nCarbohydrate\nProtein');
    });

    test('a slightly skewed photo still groups as one row', () {
      // A hand-held photo is never perfectly square-on; a few pixels of drift across
      // the row must not split it.
      final lines = [
        _line('Carbohydrate', 10, 100),
        _line('12.0g', 200, 104, width: 50),
        _line('24.0g', 300, 108, width: 50),
      ];

      expect(groupIntoRows(lines), hasLength(1));
    });

    test('genuinely separate rows are not merged', () {
      final lines = [
        _line('Carbohydrate', 10, 100),
        _line('Protein', 10, 140),
      ];

      expect(groupIntoRows(lines), hasLength(2));
    });

    test('a tall heading does not drag the rest of its row apart', () {
      // Grouping against the row's mean rather than the last line added: a big
      // "Energy" heading beside small numbers would otherwise move the reference
      // point far enough to orphan the following value.
      final lines = [
        const OcrLine(text: 'Energy', left: 10, top: 90, right: 120, bottom: 140),
        _line('550kJ', 200, 105, width: 60),
        _line('1100kJ', 300, 107, width: 60),
      ];

      expect(groupIntoRows(lines), hasLength(1));
      expect(reconstructColumns(lines), 'Energy  550kJ  1100kJ');
    });

    test('zero-height boxes do not explode into one row each', () {
      // Degenerate geometry would make a proportional tolerance zero.
      final lines = [
        const OcrLine(text: 'a', left: 0, top: 50, right: 10, bottom: 50),
        const OcrLine(text: 'b', left: 20, top: 50, right: 30, bottom: 50),
      ];

      expect(groupIntoRows(lines), hasLength(1));
    });

    test('empty input yields empty output, not a crash', () {
      expect(groupIntoRows(const []), isEmpty);
      expect(reconstructColumns(const []), '');
    });

    test('blank line text is dropped rather than padding the row', () {
      final lines = [
        _line('Carbohydrate', 10, 100),
        _line('   ', 200, 100),
        _line('12.0g', 300, 100, width: 50),
      ];

      expect(reconstructColumns(lines), 'Carbohydrate  12.0g');
    });
  });
}
