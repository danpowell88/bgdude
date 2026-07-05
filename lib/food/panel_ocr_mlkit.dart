/// On-device OCR via Google ML Kit text recognition (CameraX/ML Kit; the image never
/// leaves the device). Isolated here so the rest of the app depends only on [PanelOcr].
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'panel_ocr.dart';

class MlKitPanelOcr implements PanelOcr {
  MlKitPanelOcr()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<String> readText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  Future<void> dispose() => _recognizer.close();
}
