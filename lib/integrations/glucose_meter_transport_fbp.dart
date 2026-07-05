/// flutter_blue_plus implementation of [GlucoseMeterTransport] for the standard Bluetooth
/// Glucose Service (0x1808): scan, connect+bond, enable Glucose Measurement notifications
/// and Record Access Control Point indications, drive the RACP to fetch stored records.
///
/// Standard-profile, not Roche-specific — works with any SIG-compliant meter (Accu-Chek
/// Guide/Guide Me, Contour, etc.). The camera/pump BLE path is untouched; this is a second,
/// on-demand GATT client for a different device.
library;

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

import 'glucose_meter.dart';
import 'glucose_meter_transport.dart';

class FbpGlucoseMeterTransport implements GlucoseMeterTransport {
  final _log = Logger('GlucoseMeter');

  static final _svcGlucose = Guid('1808');
  static const _uuidMeasurement = '2a18';
  static const _uuidRacp = '2a52';

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<MeterDevice> scan({Duration timeout = const Duration(seconds: 12)}) {
    final seen = <String>{};
    final controller = StreamController<MeterDevice>();
    late final StreamSubscription<List<ScanResult>> sub;

    sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        if (!seen.add(id)) continue;
        final name = r.advertisementData.advName.trim();
        controller.add(MeterDevice(
            id: id, name: name.isEmpty ? 'Glucose meter' : name));
      }
    }, onError: controller.addError);

    controller.onCancel = () async {
      await sub.cancel();
      await stopScan();
    };

    FlutterBluePlus.startScan(withServices: [_svcGlucose], timeout: timeout)
        .catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Close the stream once the scan window elapses.
    Future<void>.delayed(timeout + const Duration(seconds: 1), () {
      if (!controller.isClosed) controller.close();
    });
    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  @override
  Future<List<GlucoseMeterReading>> fetchRecords(String deviceId,
      {int? sinceSeq}) async {
    final device = BluetoothDevice.fromId(deviceId);
    final readings = <GlucoseMeterReading>[];
    final racpDone = Completer<void>();
    final subs = <StreamSubscription<dynamic>>[];

    try {
      await device.connect(timeout: const Duration(seconds: 20));
      try {
        await device.createBond(); // Android; no-op/rejects elsewhere
      } catch (_) {/* already bonded or unsupported */}

      final services = await device.discoverServices();
      final glucose = services.firstWhere(
        (s) => s.uuid == _svcGlucose,
        orElse: () => throw StateError('No Glucose Service on this device'),
      );
      BluetoothCharacteristic? measurement;
      BluetoothCharacteristic? racp;
      for (final c in glucose.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u.contains(_uuidMeasurement)) measurement = c;
        if (u.contains(_uuidRacp)) racp = c;
      }
      if (measurement == null || racp == null) {
        throw StateError('Meter is missing the required characteristics');
      }

      subs.add(measurement.onValueReceived.listen((bytes) {
        final r = GlucoseMeasurementParser.parse(bytes);
        if (r != null) readings.add(r);
      }));
      await measurement.setNotifyValue(true);

      subs.add(racp.onValueReceived.listen((bytes) {
        final resp = Racp.parse(bytes);
        if (resp?.requestOpCode != null && !racpDone.isCompleted) {
          racpDone.complete();
        }
      }));
      await racp.setNotifyValue(true); // RACP is indicate; fbp handles it

      final cmd = sinceSeq == null
          ? Racp.reportAll()
          : Racp.reportSince(sinceSeq + 1);
      await racp.write(cmd, withoutResponse: false);

      await racpDone.future.timeout(const Duration(seconds: 25),
          onTimeout: () => _log.warning('RACP completion timed out'));
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
      try {
        await device.disconnect();
      } catch (_) {}
    }

    readings.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    return readings;
  }
}
