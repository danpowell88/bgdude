/// OCR abstraction for reading text off a nutrition-panel photo. The real implementation
/// ([MlKitPanelOcr] in `panel_ocr_mlkit.dart`) uses on-device ML Kit text recognition; the
/// interface keeps the scan service and its tests free of the native dependency.
library;

abstract interface class PanelOcr {
  /// Recognise text in the image at [imagePath] (a local file). Returns the full text with
  /// line breaks; empty string when nothing is read.
  Future<String> readText(String imagePath);
}
