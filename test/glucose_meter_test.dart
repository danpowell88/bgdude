import 'package:bgdude/integrations/glucose_meter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlucoseMeasurementParser', () {
    test('decodes a kg/L record (100 mg/dL) with base time', () {
      // flags=0x02 (concentration present, kg/L), seq=5, 2024-06-01 08:30:00,
      // SFLOAT 0xB064 = 100×10^-5 kg/L, type/location=0x11.
      final r = GlucoseMeasurementParser.parse(const [
        0x02, 0x05, 0x00, 0xE8, 0x07, 0x06, 0x01, 0x08, 0x1E, 0x00, //
        0x64, 0xB0, 0x11,
      ])!;
      expect(r.sequenceNumber, 5);
      expect(r.mgdl, closeTo(100, 0.001));
      expect(r.time, DateTime(2024, 6, 1, 8, 30, 0));
      expect(r.contextWillFollow, isFalse);
    });

    test('decodes a mol/L record with a +60 min time offset', () {
      // flags=0x07 (offset + concentration + mol/L), seq=10, 2024-01-02 03:04:05,
      // offset +60, SFLOAT 0xC037 = 55×10^-4 mol/L = 5.5 mmol/L.
      final r = GlucoseMeasurementParser.parse(const [
        0x07, 0x0A, 0x00, 0xE8, 0x07, 0x01, 0x02, 0x03, 0x04, 0x05, //
        0x3C, 0x00, 0x37, 0xC0, 0x11,
      ])!;
      expect(r.sequenceNumber, 10);
      expect(r.time, DateTime(2024, 1, 2, 4, 4, 5)); // 03:04:05 + 60 min
      expect(r.mgdl, closeTo(5.5 * 18.0182, 0.2));
    });

    test('SFLOAT special values decode to null', () {
      expect(GlucoseMeasurementParser.decodeSfloat(0x07FF), isNull); // NaN
      expect(GlucoseMeasurementParser.decodeSfloat(0x0800), isNull); // NRes
      expect(GlucoseMeasurementParser.decodeSfloat(0x0802), isNull); // -INFINITY
    });

    test('annotation-only and malformed records are skipped', () {
      // No concentration flag → nothing to import.
      expect(
          GlucoseMeasurementParser.parse(
              const [0x00, 0x01, 0x00, 0xE8, 0x07, 0x06, 0x01, 0x08, 0x1E, 0x00]),
          isNull);
      // Too short.
      expect(GlucoseMeasurementParser.parse(const [0x02, 0x01]), isNull);
      // Meter clock unset (year 0).
      expect(
          GlucoseMeasurementParser.parse(
              const [0x02, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01, 0x08, 0x1E, 0x00, 0x64, 0xB0, 0x11]),
          isNull);
    });

    test('imports as a fingerstick (calibration-flagged CgmSample)', () {
      final r = GlucoseMeasurementParser.parse(const [
        0x02, 0x05, 0x00, 0xE8, 0x07, 0x06, 0x01, 0x08, 0x1E, 0x00, //
        0x64, 0xB0, 0x11,
      ])!;
      final s = r.toCgmSample();
      expect(s.isCalibration, isTrue);
      expect(s.mgdl, closeTo(100, 0.001));
      expect(s.time, r.time);
    });
  });

  group('Racp', () {
    test('command builders match the SIG opcodes/operators', () {
      expect(Racp.reportAll(), [0x01, 0x01]);
      expect(Racp.reportNumber(), [0x04, 0x01]);
      // seq 300 = 0x012C → little-endian operand.
      expect(Racp.reportSince(300), [0x01, 0x03, 0x01, 0x2C, 0x01]);
    });

    test('parses a "number of records" indication', () {
      final r = Racp.parse(const [0x05, 0x00, 0x0A, 0x00])!;
      expect(r.numberOfRecords, 10);
    });

    test('parses success and failure response indications', () {
      final ok = Racp.parse(const [0x06, 0x00, 0x01, 0x01])!;
      expect(ok.requestOpCode, 0x01);
      expect(ok.isSuccess, isTrue);
      final fail = Racp.parse(const [0x06, 0x00, 0x01, 0x03])!;
      expect(fail.isSuccess, isFalse);
    });
  });
}
