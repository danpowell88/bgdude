import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/widget/home_widget_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the plugin glue in [HomeWidgetService] (not just the pure formatter): that a
/// pushed snapshot is written to the home_widget store under the exact keys the native
/// BgWidgetProvider reads, that a unit toggle re-pushes, and that a staleness refresh
/// re-renders. The `home_widget` MethodChannel is mocked so no platform is needed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final saved = <String, Object?>{};
  final methods = <String>[];
  Map<Object?, Object?>? lastUpdateArgs;

  setUp(() {
    saved.clear();
    methods.clear();
    lastUpdateArgs = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'saveWidgetData':
          saved[args!['id'] as String] = args['data'];
          return true;
        case 'updateWidget':
          lastUpdateArgs = args;
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final now = DateTime(2026, 7, 5, 9, 0);
  PumpSnapshot snapshot({
    int? cgmMgdl = 112,
    GlucoseTrend trend = GlucoseTrend.flat,
    double? iob = 1.2,
    Duration readingAge = const Duration(minutes: 3),
  }) =>
      PumpSnapshot(
        time: now,
        iobUnits: iob,
        cgmMgdl: cgmMgdl,
        cgmTrend: trend,
        cgmTime: now.subtract(readingAge),
      );

  HomeWidgetService service() => HomeWidgetService(now: () => now);

  test('pushUpdate writes every key the native provider reads', () async {
    await service().pushUpdate(snapshot(), GlucoseUnit.mmol);

    expect(saved['bg_text'], '6.2');
    expect(saved['bg_trend'], '→');
    expect(saved['bg_unit'], 'mmol/L');
    expect(saved['iob_text'], 'IOB 1.2 U');
    expect(saved['bg_range'], 'inRange');
    expect(saved['cgm_epoch_ms'],
        now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch);
    // And it re-renders the correct native provider.
    expect(methods, contains('updateWidget'));
    expect(lastUpdateArgs?['qualifiedAndroidName'],
        'com.bgdude.app.widget.BgWidgetProvider');
  });

  test('a low, stale reading persists the range but the provider greys it out',
      () async {
    await service().pushUpdate(
        snapshot(cgmMgdl: 60, readingAge: const Duration(minutes: 40)),
        GlucoseUnit.mgdl);
    expect(saved['bg_text'], '60');
    expect(saved['bg_range'], 'low'); // range still reported
    expect(saved['bg_unit'], 'mg/dL');
  });

  test('setUnit re-pushes the last snapshot in the new unit', () async {
    final s = service();
    await s.pushUpdate(snapshot(), GlucoseUnit.mmol);
    expect(saved['bg_text'], '6.2');

    await s.setUnit(GlucoseUnit.mgdl);
    expect(saved['bg_text'], '112');
    expect(saved['bg_unit'], 'mg/dL');
  });

  test('setUnit before any snapshot is a no-op (nothing saved)', () async {
    await service().setUnit(GlucoseUnit.mgdl);
    expect(saved, isEmpty);
    expect(methods, isEmpty);
  });

  test('refreshStaleness with no snapshot only re-renders', () async {
    await service().refreshStaleness();
    expect(saved, isEmpty);
    expect(methods, ['updateWidget']);
  });

  test('missing CGM writes placeholders and a null epoch', () async {
    await service().pushUpdate(
        PumpSnapshot(time: now, iobUnits: null, cgmMgdl: null),
        GlucoseUnit.mmol);
    expect(saved['bg_text'], '--');
    expect(saved['bg_trend'], '');
    expect(saved['iob_text'], 'IOB --');
    expect(saved['bg_range'], 'unknown');
    expect(saved.containsKey('cgm_epoch_ms'), isTrue);
    expect(saved['cgm_epoch_ms'], isNull);
  });
}
