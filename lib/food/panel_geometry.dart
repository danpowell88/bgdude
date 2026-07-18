/// Rebuilding a nutrition panel's rows from OCR geometry (issue #104).
///
/// ML Kit reads a two-column label (per-serving / per-100 g) as a set of blocks, and
/// there is no guarantee those blocks are laid out row-by-row: it commonly returns one
/// block per *column*, so the flattened `result.text` reads all the labels, then all the
/// per-serve numbers, then all the per-100 g numbers. The parser then sees
/// "Carbohydrate" on one line and its numbers three lines later, and either merges the
/// columns or gives up.
///
/// The geometry to fix that is already in the OCR result and was being discarded. This
/// file regroups lines by their vertical position, so each visual row is reassembled
/// left-to-right regardless of what order the recogniser emitted them in.
///
/// Pure — no plugin dependency, so it is testable with synthetic geometry.
library;

/// One recognised line of text with its bounding box, in image pixels.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get height => (bottom - top).abs();
}

/// Rebuilds the panel's text row by row from [lines].
///
/// Lines are grouped into rows when their vertical centres are close relative to their
/// own height, then each row is ordered left-to-right. Returns text with one visual row
/// per line, which is the shape [NutritionPanelParser] already expects.
///
/// Returns an empty string for empty input so the caller can fall back to flat OCR text
/// rather than feeding the parser something meaningless.
String reconstructColumns(List<OcrLine> lines) {
  final rows = groupIntoRows(lines);
  return rows
      .map((row) => row.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('  '))
      .where((line) => line.isNotEmpty)
      .join('\n');
}

/// Groups [lines] into visual rows, each ordered left-to-right; rows themselves are
/// ordered top-to-bottom.
///
/// The tolerance is proportional to text height rather than a fixed pixel count, because
/// the same label photographed closer produces proportionally larger boxes — a fixed
/// threshold would work at one camera distance and fail at another.
List<List<OcrLine>> groupIntoRows(List<OcrLine> lines, {double tolerance = 0.6}) {
  if (lines.isEmpty) return const [];

  final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrLine>>[];

  for (final line in sorted) {
    final current = rows.isEmpty ? null : rows.last;
    if (current != null && _belongsToRow(current, line, tolerance)) {
      current.add(line);
    } else {
      rows.add([line]);
    }
  }

  for (final row in rows) {
    row.sort((a, b) => a.left.compareTo(b.left));
  }
  return rows;
}

/// Whether [line] sits on the same visual row as [row].
///
/// Compared against the row's *mean* centre rather than only the previously added line,
/// so a tall line (a big "Energy" heading beside small numbers) doesn't drag the row's
/// reference point and split the rest of the row off from it.
bool _belongsToRow(List<OcrLine> row, OcrLine line, double tolerance) {
  final meanCenter =
      row.map((l) => l.centerY).reduce((a, b) => a + b) / row.length;
  final meanHeight = row.map((l) => l.height).reduce((a, b) => a + b) / row.length;
  // Guard against zero-height boxes (degenerate OCR output) turning the tolerance into
  // zero and putting every line on its own row.
  final reference = [meanHeight, line.height].reduce((a, b) => a > b ? a : b);
  if (reference <= 0) return (line.centerY - meanCenter).abs() < 1;
  return (line.centerY - meanCenter).abs() <= reference * tolerance;
}
