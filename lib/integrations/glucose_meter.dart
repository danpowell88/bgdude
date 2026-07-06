/// Bluetooth glucose-meter import (fingerstick BG), e.g. the Accu-Chek Guide / Guide Me.
///
/// These meters expose the **standard Bluetooth SIG Glucose Service** (0x1808) — the same
/// profile xDrip+'s generic meter support uses — so nothing here is Roche-specific:
///   * Glucose Measurement    0x2A18  (notify)  — one stored reading per notification
///   * Glucose Measurement Ctx 0x2A34 (notify)  — optional meal/context annotation
///   * Record Access Control Pt 0x2A52 (write+indicate) — "report stored records" etc.
///
/// The transport (connect, bond, enable notifications, drive the RACP) is BLE plumbing to
/// be done on the device against real hardware. This file is the deterministic, testable
/// core: decode a Glucose Measurement record into a [GlucoseMeterReading], and build the
/// RACP commands to fetch history. Imported readings are fingersticks → stored as
/// [CgmSample] with `isCalibration: true`.
library;

import '../core/samples.dart';
import '../core/units.dart';

/// One decoded stored reading from the meter.
class GlucoseMeterReading {
  const GlucoseMeterReading({
    required this.sequenceNumber,
    required this.time,
    required this.mgdl,
    this.contextWillFollow = false,
  });

  /// The meter's monotonic record id — used to fetch only newer records next sync.
  final int sequenceNumber;

  /// Reading time from the meter's clock (base time + time offset). This is the meter's
  /// local time; clock drift on the meter is a real caveat when merging with CGM.
  final DateTime time;

  final double mgdl;

  /// The record signalled that a Glucose Measurement Context notification follows.
  final bool contextWillFollow;

  /// Import target: a fingerstick, flagged as a calibration-type reading (not a sensor
  /// value) so analytics can treat it distinctly.
  CgmSample toCgmSample() => CgmSample(
        time: time,
        mgdl: mgdl,
        isCalibration: true,
        source: GlucoseSource.meter,
      );
}

/// Parser for the Glucose Measurement characteristic (0x2A18).
class GlucoseMeasurementParser {
  /// Decode an IEEE-11073 16-bit SFLOAT. Returns null for the reserved/NaN/NRes/±INFINITY
  /// special values (those aren't real readings).
  static double? decodeSfloat(int raw) {
    final mantissaRaw = raw & 0x0FFF;
    var exponent = (raw >> 12) & 0x0F;
    // Special mantissa values per the spec.
    const nan = 0x07FF, nres = 0x0800, posInf = 0x07FE, negInf = 0x0802, reserved = 0x0801;
    if (mantissaRaw == nan ||
        mantissaRaw == nres ||
        mantissaRaw == posInf ||
        mantissaRaw == negInf ||
        mantissaRaw == reserved) {
      return null;
    }
    var mantissa = mantissaRaw;
    if (mantissa >= 0x0800) mantissa -= 0x1000; // 12-bit two's complement
    if (exponent >= 0x08) exponent -= 0x10; // 4-bit two's complement
    return mantissa * _pow10(exponent);
  }

  static double _pow10(int e) {
    var v = 1.0;
    if (e >= 0) {
      for (var i = 0; i < e; i++) {
        v *= 10;
      }
    } else {
      for (var i = 0; i < -e; i++) {
        v /= 10;
      }
    }
    return v;
  }

  /// Parse a Glucose Measurement (0x2A18) record. Returns null if the packet is malformed
  /// or carries no concentration (some records are annotation-only).
  static GlucoseMeterReading? parse(List<int> data) {
    if (data.length < 10) return null;
    final flags = data[0];
    final timeOffsetPresent = flags & 0x01 != 0;
    final concentrationPresent = flags & 0x02 != 0;
    final unitsMolPerL = flags & 0x04 != 0; // 0 = kg/L, 1 = mol/L
    final contextFollows = flags & 0x10 != 0;

    final seq = data[1] | (data[2] << 8);
    final year = data[3] | (data[4] << 8);
    final month = data[5], day = data[6];
    final hour = data[7], minute = data[8], second = data[9];
    if (year == 0 || month == 0 || day == 0) return null; // meter clock unset

    var idx = 10;
    var offsetMinutes = 0;
    if (timeOffsetPresent) {
      if (data.length < idx + 2) return null;
      var off = data[idx] | (data[idx + 1] << 8);
      if (off >= 0x8000) off -= 0x10000; // sint16
      offsetMinutes = off;
      idx += 2;
    }

    if (!concentrationPresent) return null; // annotation-only record — nothing to import
    if (data.length < idx + 2) return null;
    final sfloat = data[idx] | (data[idx + 1] << 8);
    final concentration = decodeSfloat(sfloat);
    if (concentration == null || concentration <= 0) return null;

    // kg/L → mg/dL is ×100000; mol/L → mmol/L is ×1000, then mmol/L → mg/dL.
    final mgdl = unitsMolPerL
        ? concentration * 1000.0 * kMgdlPerMmol
        : concentration * 100000.0;

    final time = DateTime(year, month, day, hour, minute, second)
        .add(Duration(minutes: offsetMinutes));

    return GlucoseMeterReading(
      sequenceNumber: seq,
      time: time,
      mgdl: mgdl,
      contextWillFollow: contextFollows,
    );
  }
}

/// The meter's report of how a Record Access Control Point request resolved.
class RacpResponse {
  const RacpResponse({this.numberOfRecords, this.requestOpCode, this.responseCode});

  /// For a "number of stored records" reply.
  final int? numberOfRecords;

  /// For a general response: which request it answers, and the result code (1 = success).
  final int? requestOpCode;
  final int? responseCode;

  bool get isSuccess => responseCode == 1;
}

/// Builders/parsers for the Record Access Control Point (0x2A52).
class Racp {
  Racp._();

  // Op codes.
  static const _opReportRecords = 0x01;
  static const _opReportNumber = 0x04;
  static const _opNumberResponse = 0x05;
  static const _opResponse = 0x06;
  // Operators.
  static const _opAll = 0x01;
  static const _opGreaterOrEqual = 0x03;
  // Filter type.
  static const _filterSequenceNumber = 0x01;

  /// Report every stored record.
  static List<int> reportAll() => const [_opReportRecords, _opAll];

  /// Report records with sequence number ≥ [seq] (incremental sync after the first pull).
  static List<int> reportSince(int seq) => [
        _opReportRecords,
        _opGreaterOrEqual,
        _filterSequenceNumber,
        seq & 0xFF,
        (seq >> 8) & 0xFF,
      ];

  /// Ask how many records are stored (drives progress / bounds the pull).
  static List<int> reportNumber() => const [_opReportNumber, _opAll];

  /// Parse a RACP indication.
  static RacpResponse? parse(List<int> data) {
    if (data.isEmpty) return null;
    switch (data[0]) {
      case _opNumberResponse:
        if (data.length < 4) return null;
        return RacpResponse(numberOfRecords: data[2] | (data[3] << 8));
      case _opResponse:
        if (data.length < 4) return null;
        return RacpResponse(requestOpCode: data[2], responseCode: data[3]);
      default:
        return null;
    }
  }
}
