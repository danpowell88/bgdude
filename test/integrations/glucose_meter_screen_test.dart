import 'dart:async';

import 'package:bgdude/integrations/glucose_meter.dart';
import 'package:bgdude/integrations/glucose_meter_transport.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/glucose_meter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A scan whose devices arrive on our own schedule, so the test can dispose the screen
/// between starting a scan and a result landing.
class _FakeTransport implements GlucoseMeterTransport {
  final _controller = StreamController<MeterDevice>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<MeterDevice> scan({Duration timeout = const Duration(seconds: 12)}) =>
      _controller.stream;

  @override
  Future<void> stopScan() async {}

  @override
  Future<List<GlucoseMeterReading>> fetchRecords(String deviceId, {int? sinceSeq}) async =>
      const [];

  void deliver(MeterDevice d) => _controller.add(d);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.reset());

  // Leaving the screen mid-scan used to throw setState-after-dispose when a
  // scan result (or the isAvailable() check itself) resolved after the widget was gone.
  testWidgets('disposing mid-scan then delivering a result does not throw', (tester) async {
    final transport = _FakeTransport();
    final navigatorKey = GlobalKey<NavigatorState>();

    // Push (rather than replace the whole tree) so leaving the screen unmounts only
    // GlucoseMeterScreen -- ProviderScope stays alive, matching real navigation instead
    // of tearing down the provider container along with the screen.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [glucoseMeterTransportProvider.overrideWithValue(transport)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    unawaited(navigatorKey.currentState!
        .push(MaterialPageRoute(builder: (_) => const GlucoseMeterScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan for meter'));
    await tester.pump(); // isAvailable() resolves, scan starts
    expect(find.text('Scanning…'), findsOneWidget);

    // Leave the screen while the scan is still in flight.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    // A result arriving after dispose must not throw setState-after-dispose.
    transport.deliver(const MeterDevice(id: 'AA:BB', name: 'Accu-Chek Guide Me'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
