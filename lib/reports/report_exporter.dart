/// Turns a [GlucoseReport] into shareable artifacts: a clinician-ready PDF and CSVs
/// (a metrics summary + the raw confirmed readings). The byte/string builders are pure
/// and unit-tested; [shareGlucoseReport] does the file IO + system share sheet.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/samples.dart';
import '../core/units.dart';
import 'clinic_prep.dart';
import 'glucose_report.dart';

class ReportExporter {
  const ReportExporter();

  // ---- CSV (pure) ----------------------------------------------------------

  /// Metrics + episode summary as `field,value` CSV.
  String summaryCsv(GlucoseReport r, GlucoseUnit unit) {
    final m = r.metrics;
    String g(double mgdl) => Mgdl(mgdl).display(unit);
    final rows = <List<String>>[
      ['field', 'value'],
      ['range', r.range.label],
      ['from', r.range.from.toIso8601String()],
      ['to', r.range.to.toIso8601String()],
      ['days_with_data', '${r.daysWithData}'],
      ['unit', unit.label],
      ['readings', '${m.readingCount}'],
      ['cgm_active_pct', (m.activeFraction * 100).toStringAsFixed(1)],
      ['sufficient_for_agp', '${m.sufficient}'],
      ['mean_glucose', g(m.meanMgdl)],
      // TASK-164: GMI (Bergenstal) and eA1c (ADAG eAG-derived) are different
      // quantities and this codebase only computes GMI — the header must say so,
      // not imply an eA1c a clinician could mistake for a lab A1c equivalent.
      ['gmi_pct', m.gmi.toStringAsFixed(1)],
      ['cv_pct', m.cvPercent.toStringAsFixed(1)],
      ['cv_high_ge36', '${m.variabilityHigh}'],
      ['gri', m.gri.toStringAsFixed(1)],
      ['lbgi', m.lbgi.toStringAsFixed(2)],
      ['hbgi', m.hbgi.toStringAsFixed(2)],
      ['tir_70_180_pct', (m.timeInRange * 100).toStringAsFixed(1)],
      ['titr_70_140_pct', (m.timeInTightRange * 100).toStringAsFixed(1)],
      ['tbr_below_70_pct', (m.timeBelow70 * 100).toStringAsFixed(1)],
      ['tbr_below_54_pct', (m.timeBelow54 * 100).toStringAsFixed(1)],
      ['tar_above_180_pct', (m.timeAbove180 * 100).toStringAsFixed(1)],
      ['tar_above_250_pct', (m.timeAbove250 * 100).toStringAsFixed(1)],
      ['low_episodes', '${r.lowEpisodes.length}'],
      ['high_episodes', '${r.highEpisodes.length}'],
      ['excluded_artifact_readings', '${r.excludedSampleCount}'],
    ];
    return _toCsv(rows);
  }

  /// Raw confirmed readings as `timestamp_iso,mgdl,display` CSV — for the user's own
  /// analysis in a spreadsheet.
  String rawReadingsCsv(List<CgmSample> samples, GlucoseUnit unit) {
    final rows = <List<String>>[
      ['timestamp_iso', 'mgdl', unit.label],
      for (final s in samples)
        [
          s.time.toIso8601String(),
          s.mgdl.round().toString(),
          Mgdl(s.mgdl).display(unit),
        ],
    ];
    return _toCsv(rows);
  }

  static String _toCsv(List<List<String>> rows) =>
      rows.map((r) => r.map(_escape).join(',')).join('\n');

  static String _escape(String v) =>
      v.contains(',') || v.contains('"') || v.contains('\n')
          ? '"${v.replaceAll('"', '""')}"'
          : v;

  // ---- PDF (pure) ----------------------------------------------------------

  Future<Uint8List> buildPdf(GlucoseReport r, GlucoseUnit unit) async {
    final m = r.metrics;
    final doc = pw.Document();
    String g(double mgdl) => '${Mgdl(mgdl).display(unit)} ${unit.label}';
    String pct(double f) => '${(f * 100).toStringAsFixed(1)}%';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('bgdude Glucose Report')),
        pw.Text('${r.range.label}  -  ${r.daysWithData} days with data'),
        pw.Text('Generated ${_fmtDate(r.generatedAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        if (!m.sufficient)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.all(6),
            color: PdfColors.amber100,
            child: pw.Text(
              'Limited data: ${pct(m.activeFraction)} CGM active over '
              '${r.daysWithData} days. Interpret with caution (AGP wants at least '
              '14 days and 70% active).',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Key metrics')),
        _kv(<List<String>>[
          ['Mean glucose', g(m.meanMgdl)],
          ['GMI (glucose management indicator)', '${m.gmi.toStringAsFixed(1)}%'],
          [
            'Glucose variability (CV)',
            '${m.cvPercent.toStringAsFixed(1)}%'
                '${m.variabilityHigh ? ' (high, >=36%)' : ''}'
          ],
          ['Glycemia Risk Index (GRI)', m.gri.toStringAsFixed(0)],
          ['LBGI / HBGI', '${m.lbgi.toStringAsFixed(1)} / ${m.hbgi.toStringAsFixed(1)}'],
          ['Readings', '${m.readingCount}'],
          ['CGM active time', pct(m.activeFraction)],
        ]),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Time in ranges')),
        _kv(<List<String>>[
          ['Very high (>250)', pct(m.timeAbove250)],
          ['High (>180)', pct(m.timeAbove180)],
          ['In range (70-180)', pct(m.timeInRange)],
          ['Tight range (70-140)', pct(m.timeInTightRange)],
          ['Low (<70)', pct(m.timeBelow70)],
          ['Very low (<54)', pct(m.timeBelow54)],
        ]),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Ambulatory glucose profile (hourly)')),
        _agpTable(r, unit),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Episodes')),
        pw.Text('${r.lowEpisodes.length} low, ${r.highEpisodes.length} high '
            '(15+ min).'),
        if (r.lowEpisodes.isNotEmpty || r.highEpisodes.isNotEmpty)
          _episodeTable(r, unit),
        pw.SizedBox(height: 16),
        pw.Text(
          'Informational only - read-only companion data, not a substitute for your '
          'CGM/pump or clinical advice. Sensor artifacts (warm-up, confirmed '
          'compression lows) are excluded.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ));
    return doc.save();
  }

  pw.Widget _kv(List<List<String>> rows) => pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          for (final row in rows)
            pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text(row[0])),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text(row[1],
                      // ignore: prefer_const_constructors
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
        ],
      );

  pw.Widget _agpTable(GlucoseReport r, GlucoseUnit unit) {
    String g(double v) => Mgdl(v).display(unit);
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final h in ['Hour', '5%', '25%', 'Median', '75%', '95%'])
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(h,
                      // ignore: prefer_const_constructors
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        for (final b in r.agp)
          pw.TableRow(children: [
            for (final cell in [
              '${(b.minuteOfDay ~/ 60).toString().padLeft(2, '0')}:00',
              g(b.p05),
              g(b.p25),
              g(b.median),
              g(b.p75),
              g(b.p95),
            ])
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8))),
          ]),
      ],
    );
  }

  pw.Widget _episodeTable(GlucoseReport r, GlucoseUnit unit) {
    final all = [...r.lowEpisodes, ...r.highEpisodes]
      ..sort((a, b) => b.start.compareTo(a.start));
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final h in ['When', 'Type', 'Extreme', 'Duration'])
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(h,
                      // ignore: prefer_const_constructors
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        for (final e in all.take(30))
          pw.TableRow(children: [
            for (final cell in [
              _fmtDate(e.start),
              e.isLow ? 'Low' : 'High',
              '${Mgdl(e.extremeMgdl).display(unit)} ${unit.label}',
              '${e.duration.inMinutes} min',
            ])
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8))),
          ]),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---- Clinic-visit prep (§4-4.4) ------------------------------------------

  /// A short, print-ready one-pager: the plain-language summary plus the suggested
  /// questions. Reuses this same PDF pipeline (AC#3).
  Future<Uint8List> buildClinicPrepPdf(ClinicPrep prep, DateTime generatedAt) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('bgdude clinic-visit prep')),
        pw.Text('${prep.rangeLabel}  -  generated ${_fmtDate(generatedAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Summary')),
        pw.Text(prep.summary),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, child: pw.Text('Questions to ask')),
        for (final q in prep.questions) pw.Bullet(text: q),
        pw.SizedBox(height: 16),
        pw.Text(
          'Informational only - read-only companion data, not a substitute for your '
          'CGM/pump or clinical advice. Targets referenced are the ADA/ATTD consensus.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ));
    return doc.save();
  }

  // ---- Share (IO) ----------------------------------------------------------

  /// Build the clinic-prep PDF, write it to a temp dir, and open the system share sheet.
  Future<void> shareClinicPrep(ClinicPrep prep, DateTime generatedAt) async {
    final dir = await getTemporaryDirectory();
    final stamp = generatedAt.millisecondsSinceEpoch;
    final bytes = await buildClinicPrepPdf(prep, generatedAt);
    final file = File('${dir.path}/clinic_prep_$stamp.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'bgdude clinic-visit prep — ${prep.rangeLabel}',
    );
  }

  /// Build the PDF + CSVs, write them to a temp dir, and open the system share sheet.
  Future<void> shareGlucoseReport({
    required GlucoseReport report,
    required List<CgmSample> confirmed,
    required GlucoseUnit unit,
  }) async {
    final dir = await getTemporaryDirectory();
    final stamp = report.generatedAt.millisecondsSinceEpoch;
    final pdfBytes = await buildPdf(report, unit);

    final pdfFile = File('${dir.path}/glucose_report_$stamp.pdf');
    final summaryFile = File('${dir.path}/glucose_summary_$stamp.csv');
    final rawFile = File('${dir.path}/glucose_readings_$stamp.csv');
    await pdfFile.writeAsBytes(pdfBytes);
    await summaryFile.writeAsString(summaryCsv(report, unit));
    await rawFile.writeAsString(rawReadingsCsv(confirmed, unit));

    await Share.shareXFiles(
      [
        XFile(pdfFile.path, mimeType: 'application/pdf'),
        XFile(summaryFile.path, mimeType: 'text/csv'),
        XFile(rawFile.path, mimeType: 'text/csv'),
      ],
      subject: 'bgdude glucose report — ${report.range.label}',
    );
  }
}
