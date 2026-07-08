import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/integrations/glucose_meter.dart';
import 'package:bgdude/integrations/glucose_meter_controller.dart';
import 'package:bgdude/integrations/glucose_meter_service.dart';
import 'package:bgdude/integrations/glucose_meter_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// A transport whose [fetchRecords] always fails the way a real BLE transport does when
/// the paired device isn't a standard glucose meter.
class _NoGlucoseServiceTransport implements GlucoseMeterTransport {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<MeterDevice> scan({Duration timeout = const Duration(seconds: 12)}) =>
      const Stream.empty();
  @override
  Future<void> stopScan() async {}
  @override
  Future<List<GlucoseMeterReading>> fetchRecords(String deviceId,
          {int? sinceSeq}) =>
      throw StateError('No Glucose Service on this device');
}

void main() {
  setUp(KvStore.useMemory);

  test(
      'pairing an incompatible BLE device surfaces a clean message, not a raw StateError',
      () async {
    final controller = GlucoseMeterController(
      service: GlucoseMeterService(
        transport: _NoGlucoseServiceTransport(),
        repository: InMemoryHistoryRepository(),
      ),
      transport: _NoGlucoseServiceTransport(),
    );

    await controller.pair(const MeterDevice(id: 'not-a-meter', name: 'Watch'));

    expect(controller.state.error, "That device isn't a standard glucose meter.");
    expect(controller.state.syncing, isFalse);
  });
}
