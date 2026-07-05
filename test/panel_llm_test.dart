import 'package:bgdude/food/panel_llm.dart';
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
}
