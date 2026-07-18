/// OCR abstraction for reading text off a nutrition-panel photo. The real implementation
/// ([MlKitPanelOcr] in `panel_ocr_mlkit.dart`) uses on-device ML Kit text recognition; the
/// interface keeps the scan service and its tests free of the native dependency.
library;

import 'panel_geometry.dart';

abstract interface class PanelOcr {
  /// Recognise text in the image at [imagePath] (a local file). Returns the full text with
  /// line breaks; empty string when nothing is read.
  Future<String> readText(String imagePath);
}

/// An OCR implementation that can also report per-line geometry (issue #104).
///
/// Kept separate from [PanelOcr] rather than added to it so that implementations which
/// only have flat text — including the test fakes — stay valid, and so the scan service
/// has an explicit "no geometry available" path to degrade to.
abstract interface class PanelOcrWithGeometry implements PanelOcr {
  /// Recognised lines with bounding boxes. Empty when nothing is read.
  Future<List<OcrLine>> readLines(String imagePath);
}
