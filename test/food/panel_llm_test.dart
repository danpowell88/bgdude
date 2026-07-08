import 'package:bgdude/food/panel_llm.dart';
import 'package:bgdude/food/panel_llm_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a clean JSON response with both columns', () {
    const resp = '''
{"serving_size_g":30,"servings_per_package":12,
"carbs":{"per_serve":19.2,"per_100g":64.0},
"fat":{"per_serve":0.4,"per_100g":1.3},
"protein":{"per_serve":3.4,"per_100g":11.3},
"sodium_mg":{"per_serve":85,"per_100g":283}}''';
    final p = parsePanelLlmJson(resp, rawText: 'ocr')!;
    expect(p.servingSizeG, 30);
    expect(p.carbs.per100g, closeTo(64.0, 0.01));
    expect(p.fat.perServe, closeTo(0.4, 0.01));
    expect(p.protein.per100g, closeTo(11.3, 0.01));
    expect(p.rawText, 'ocr');
    expect(p.source, contains('AI'));
  });

  test('tolerates prose/markdown around the JSON', () {
    const resp =
        'Sure! Here is the data:\n```json\n{"carbs":{"per_100g":40}}\n```\nHope that helps.';
    final p = parsePanelLlmJson(resp)!;
    expect(p.carbs.per100g, 40);
  });

  test('tolerates a bare scalar and string numbers', () {
    final p = parsePanelLlmJson('{"carbs":42,"fat":"1,3"}')!;
    expect(p.carbs.per100g, 42); // scalar → per-100 g
    expect(p.fat.per100g, closeTo(1.3, 0.01)); // comma decimal in a string
  });

  test('returns null when no macros or no JSON', () {
    expect(parsePanelLlmJson('no json here'), isNull);
    expect(parsePanelLlmJson('{"serving_size_g":30}'), isNull);
    expect(parsePanelLlmJson('{bad json'), isNull);
  });

  test('prompt embeds the OCR text and asks for JSON only', () {
    final prompt = buildPanelPrompt('Carbohydrate 40g');
    expect(prompt, contains('Carbohydrate 40g'));
    expect(prompt.toLowerCase(), contains('json'));
  });

  test('NoopPanelLlm is unavailable and yields nothing', () async {
    const llm = NoopPanelLlm();
    expect(llm.available, isFalse);
    expect(await llm.extract('anything'), isNull);
  });

  test('5-1: out-of-range macro is nulled (per-100g > 100)', () {
    // 900 g carbs / 100 g is impossible; grounded (900 is in the text) but out of bounds.
    final p = parsePanelLlmJson(
        '{"carbs":{"per_100g":900},"fat":{"per_100g":5}}',
        rawText: 'carbs 900 fat 5')!;
    expect(p.carbs.per100g, isNull);
    expect(p.fat.per100g, 5);
  });

  test('5-1: sugars cannot exceed carbs', () {
    final p = parsePanelLlmJson(
        '{"carbs":{"per_100g":40},"sugars":{"per_100g":90}}',
        rawText: 'carbs 40 sugars 90')!;
    expect(p.carbs.per100g, 40);
    expect(p.sugars.per100g, isNull); // 90 > 40 → dropped
  });

  test('5-1: inconsistent per-serve vs per-100g×serving is dropped', () {
    // serving 30 g, per-100g 50 → expected per-serve ≈ 15; the LLM said 40 (>25% off).
    final p = parsePanelLlmJson(
        '{"serving_size_g":30,"carbs":{"per_serve":40,"per_100g":50}}',
        rawText: 'serving 30 g carbs 40 per serve 50 per 100')!;
    expect(p.carbs.per100g, 50);
    expect(p.carbs.perServe, isNull);
  });

  test('5-2: an ungrounded number (not on the label) is rejected', () {
    // The label text mentions fat 5 but no 64 — the carbs value is a hallucination.
    final p = parsePanelLlmJson(
        '{"carbs":{"per_100g":64},"fat":{"per_100g":5}}',
        rawText: 'total fat 5 g per 100 g')!;
    expect(p.carbs.per100g, isNull);
    expect(p.fat.per100g, 5);
  });

  test('5-2: grounding is skipped when there is no OCR text to check', () {
    final p = parsePanelLlmJson('{"carbs":{"per_100g":64}}', rawText: '')!;
    expect(p.carbs.per100g, 64);
  });

  group('GemmaPanelExtractor', () {
    test(
        'a model-load failure calls onModelLoadFailed and still returns null '
        '(falls back to the deterministic parser)', () async {
      // FlutterGemma.getActiveModel() has no native LiteRT runtime to load on this
      // desktop test host, so it always throws here -- exactly the same failure
      // shape as a genuinely corrupt/truncated model file failing to load on a
      // real device, which is what this callback exists to catch.
      Object? capturedError;
      final extractor = GemmaPanelExtractor(
        onModelLoadFailed: (e) => capturedError = e,
      );

      final result = await extractor.extract('Total carbohydrate 40 g');

      expect(result, isNull);
      expect(capturedError, isNotNull);
    });
  });
}
