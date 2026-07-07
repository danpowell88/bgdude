import 'package:bgdude/food/nutrition_panel.dart';
import 'package:bgdude/food/panel_llm.dart';
import 'package:bgdude/food/panel_ocr.dart';
import 'package:bgdude/food/panel_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOcr implements PanelOcr {
  _FakeOcr(this.text);
  final String text;
  @override
  Future<String> readText(String imagePath) async => text;
}

class _ThrowingOcr implements PanelOcr {
  @override
  Future<String> readText(String imagePath) async =>
      throw Exception('ML Kit: corrupt image');
}

class _FakeLlm implements PanelLlmExtractor {
  _FakeLlm(this._panel);
  final PanelNutrition? _panel;
  @override
  bool get available => true;
  int calls = 0;
  @override
  Future<PanelNutrition?> extract(String ocrText) async {
    calls++;
    return _panel;
  }
}

class _ThrowingLlm implements PanelLlmExtractor {
  @override
  bool get available => true;
  @override
  Future<PanelNutrition?> extract(String ocrText) async =>
      throw Exception('model inference failed');
}

const _goodAu = '''
Per Serve   Per 100g
Carbohydrate 19.2g 64.0g
Fat, total 0.4g 1.3g
Protein 3.4g 11.3g
Serving size: 30g
''';

void main() {
  test('deterministic parse wins and the LLM is not called', () async {
    final llm = _FakeLlm(null);
    final svc = PanelScanService(ocr: _FakeOcr(_goodAu), llm: llm);
    final r = await svc.scan('x.jpg');
    expect(r.hasResult, isTrue);
    expect(r.usedLlm, isFalse);
    expect(r.panel!.carbs.per100g, closeTo(64.0, 0.01));
    expect(llm.calls, 0, reason: 'high-confidence parse should skip the LLM');
  });

  test('5-3: a carbs-only parse is not "good enough" — the LLM still runs', () async {
    // Parser finds only carbs (confidence 0.6); a fuller, grounded LLM result should win.
    const carbsOnly = 'Carbohydrate 64.0g';
    const aiPanel = PanelNutrition(
      carbs: PanelValue(per100g: 64),
      protein: PanelValue(per100g: 11),
    );
    final llm = _FakeLlm(aiPanel);
    final svc = PanelScanService(ocr: _FakeOcr(carbsOnly), llm: llm);
    final r = await svc.scan('x.jpg');
    expect(llm.calls, 1, reason: 'a thin carbs-only parse must not block the LLM');
    expect(r.usedLlm, isTrue);
    expect(r.panel!.protein.per100g, 11);
  });

  test('falls back to the LLM when the parser finds nothing', () async {
    // Japanese label — outside the parser's Latin-script keyword set.
    const foreign = '栄養成分表示\n炭水化物 64g\nタンパク質 11g';
    const aiPanel = PanelNutrition(carbs: PanelValue(per100g: 64));
    final llm = _FakeLlm(aiPanel);
    final svc = PanelScanService(ocr: _FakeOcr(foreign), llm: llm);
    final r = await svc.scan('x.jpg');
    expect(llm.calls, 1);
    expect(r.usedLlm, isTrue);
    expect(r.panel!.carbs.per100g, 64);
    expect(r.panel!.rawText, foreign); // OCR text threaded through
  });

  test('no LLM available → parser-only, may be null', () async {
    const foreign = '栄養成分表示\n炭水化物 64g'; // Japanese, unsupported script
    final svc = PanelScanService(
        ocr: _FakeOcr(foreign), llm: const NoopPanelLlm());
    final r = await svc.scan('x.jpg');
    expect(r.usedLlm, isFalse);
    expect(r.panel, isNull); // parser can't read it; no fallback
  });

  test('empty OCR yields no result', () async {
    final svc = PanelScanService(ocr: _FakeOcr('   '));
    final r = await svc.scan('x.jpg');
    expect(r.hasResult, isFalse);
  });

  // TASK-208(e): ocr.readText() used to run outside scan()'s try block — safe only
  // because the sole caller (meal_library_screen.dart) happens to wrap the whole call.
  // Guarding at the source means PanelScanService is safe regardless of the caller.
  test('a throwing OCR degrades to "no result" instead of propagating', () async {
    final svc = PanelScanService(ocr: _ThrowingOcr());
    final r = await svc.scan('x.jpg');
    expect(r.hasResult, isFalse);
    expect(r.ocrText, isEmpty);
  });

  // TASK-214(1): the LLM extract() throw path (scan()'s catch falling back to
  // whatever the deterministic parser managed) had no test.
  test('a throwing LLM falls back to the parser result, usedLlm false, no throw',
      () async {
    // Carbs-only parse (confidence 0.6) is below the LLM threshold, so the LLM runs
    // and throws -- the parser's own (thinner) result must still come back.
    const carbsOnly = 'Carbohydrate 64.0g';
    final svc = PanelScanService(ocr: _FakeOcr(carbsOnly), llm: _ThrowingLlm());

    final r = await svc.scan('x.jpg');

    expect(r.usedLlm, isFalse);
    expect(r.panel, isNotNull);
    expect(r.panel!.carbs.perServe, closeTo(64.0, 0.01));
  });
}
