import 'package:bgdude/food/panel_model_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PanelModelManager.fileNameFor', () {
    test('uses the last URL path segment as the model id', () {
      expect(
        PanelModelManager.fileNameFor(
            'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task'),
        'gemma3-1b-it-int4.task',
      );
    });

    test('ignores query strings', () {
      expect(
        PanelModelManager.fileNameFor(
            'https://example.com/models/panel.task?download=true'),
        'panel.task',
      );
    });

    test('falls back to a default when the URL has no filename', () {
      expect(PanelModelManager.fileNameFor('https://example.com/'),
          'panel-llm.task');
      expect(PanelModelManager.fileNameFor(''), 'panel-llm.task');
    });
  });
}
