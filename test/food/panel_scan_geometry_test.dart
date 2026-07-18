/// End-to-end column reconstruction through the scan service (issue #104).
library;

import 'package:bgdude/food/nutrition_panel.dart';
import 'package:bgdude/food/panel_geometry.dart';
import 'package:bgdude/food/nutrition_panel_parser.dart';
import 'package:bgdude/food/panel_llm.dart';
import 'package:bgdude/food/panel_ocr.dart';
import 'package:bgdude/food/panel_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// An OCR that reports geometry, mimicking ML Kit returning one block per COLUMN:
/// `readText` flattens block-by-block (all labels, then per-serve, then per-100 g),
/// while `readLines` still carries the true positions.
class _ColumnBlockOcr implements PanelOcrWithGeometry {
  @override
  Future<String> readText(String imagePath) async => [
        'Serving size 30g',
        'Per serve  Per 100g',
        'Energy',
        'Carbohydrate',
        'Protein',
        '550kJ',
        '12.0g',
        '4.0g',
        '1830kJ',
        '40.0g',
        '13.3g',
      ].join('\n');

  @override
  Future<List<OcrLine>> readLines(String imagePath) async => [
        _l('Serving size 30g', 10, 20, 200),
        _l('Per serve', 200, 60, 80),
        _l('Per 100g', 300, 60, 80),
        _l('Energy', 10, 100, 90),
        _l('Carbohydrate', 10, 140, 120),
        _l('Protein', 10, 180, 80),
        _l('550kJ', 200, 100, 60),
        _l('12.0g', 200, 140, 60),
        _l('4.0g', 200, 180, 60),
        _l('1830kJ', 300, 100, 60),
        _l('40.0g', 300, 140, 60),
        _l('13.3g', 300, 180, 60),
      ];
}

/// Geometry that throws — the optimisation must never break a scan flat text can serve.
class _ThrowingGeometryOcr implements PanelOcrWithGeometry {
  @override
  Future<String> readText(String imagePath) async =>
      'Per 100g\nCarbohydrate 12.0g 40.0g\nProtein 4.0g 13.3g\nEnergy 550kJ 1830kJ';

  @override
  Future<List<OcrLine>> readLines(String imagePath) async =>
      throw Exception('ML Kit geometry unavailable');
}

/// Reports no lines at all (e.g. a blank frame) — must fall back, not blank the result.
class _NoGeometryLinesOcr implements PanelOcrWithGeometry {
  @override
  Future<String> readText(String imagePath) async =>
      'Per 100g\nCarbohydrate 12.0g 40.0g\nProtein 4.0g 13.3g\nEnergy 550kJ 1830kJ';

  @override
  Future<List<OcrLine>> readLines(String imagePath) async => const [];
}

OcrLine _l(String text, double left, double top, double width) => OcrLine(
      text: text,
      left: left,
      top: top,
      right: left + width,
      bottom: top + 20,
    );

class _UnavailableLlm implements PanelLlmExtractor {
  @override
  bool get available => false;
  @override
  Future<PanelNutrition?> extract(String ocrText) async => null;
}

void main() {
  test('column-per-block OCR is rebuilt into correct per-serve/per-100g columns',
      () async {
    final svc = PanelScanService(ocr: _ColumnBlockOcr(), llm: _UnavailableLlm());

    final result = await svc.scan('label.jpg');
    final panel = result.panel!;

    // The values a human reads off the label.
    expect(panel.carbs.perServe, 12.0);
    expect(panel.carbs.per100g, 40.0);
    expect(panel.protein.perServe, 4.0);
    expect(panel.protein.per100g, 13.3);
    expect(panel.energyKj.perServe, 550);
    expect(panel.energyKj.per100g, 1830);
    // No LLM involved — the whole point is fixing this deterministically.
    expect(result.usedLlm, isFalse);
  });

  test('the flat text alone gets this label WRONG — the fix is doing real work',
      () async {
    // Guards against the reconstruction being quietly reverted: parsing the same
    // OCR without geometry does not produce the right answer. If this ever starts
    // passing, the flat path improved and the test above is no longer proving much.
    final flat = await _ColumnBlockOcr().readText('label.jpg');
    final viaFlat = const NutritionPanelParser().parse(flat);

    final rightAnswer = viaFlat != null &&
        viaFlat.carbs.perServe == 12.0 &&
        viaFlat.carbs.per100g == 40.0 &&
        viaFlat.protein.perServe == 4.0;
    expect(rightAnswer, isFalse,
        reason: 'flat OCR text should NOT already parse this correctly');
  });

  test('geometry that throws falls back to flat text', () async {
    final svc =
        PanelScanService(ocr: _ThrowingGeometryOcr(), llm: _UnavailableLlm());

    final panel = (await svc.scan('label.jpg')).panel;

    expect(panel, isNotNull);
    expect(panel!.carbs.perServe, 12.0);
  });

  test('empty geometry falls back to flat text', () async {
    final svc =
        PanelScanService(ocr: _NoGeometryLinesOcr(), llm: _UnavailableLlm());

    final panel = (await svc.scan('label.jpg')).panel;

    expect(panel, isNotNull);
    expect(panel!.carbs.per100g, 40.0);
  });
}
