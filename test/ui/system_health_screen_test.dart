import 'package:bgdude/insights/system_health.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/system_health_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-265: SystemHealthScreen now renders a third stale/amber state (distinct
/// from red-unhealthy/green-healthy) for a subsystem with no recorded failures but
/// no recent success either -- exercises the actual icon/colour selection logic in
/// _SubsystemTile, not just the underlying SubsystemHealth.isStale data-layer logic
/// (already covered directly in system_health_test.dart).
class _FixedHealthNotifier extends SystemHealthNotifier {
  _FixedHealthNotifier(SystemHealthReport report) {
    // Set synchronously, after super()'s own (unawaited) _restore() has been
    // scheduled but before it can resolve -- load() below returns null, so that
    // restore is a no-op and never overwrites this.
    state = report;
  }

  @override
  Future<SystemHealthReport?> load() async => null;

  @override
  Future<void> store(SystemHealthReport v) async {}
}

Future<void> _pumpScreen(WidgetTester tester, SystemHealthReport report) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        systemHealthProvider.overrideWith((ref) => _FixedHealthNotifier(report)),
        garminHealthProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: SystemHealthScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a subsystem with an old last-success and no recent attempt reads stale '
      '(amber warning icon), not healthy (green check)', (tester) async {
    final longAgo = DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
        .subtract(const Duration(hours: 72));
    final report = const SystemHealthReport().withRecord(
        Subsystem.healthSync, SubsystemHealth.unknown.withSuccess(longAgo));

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget,
        reason: 'healthSync has a real 48h cadence and hasn\'t succeeded in 72h '
            'with zero recorded failures -- this is exactly the silent-stall case '
            'the stale state exists to catch');
    expect(find.textContaining('no recent activity'), findsOneWidget);
    // A genuinely unhealthy row must still be distinguishable -- stale is not the
    // same icon/wording as a real recorded failure.
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('a recent success reads healthy (green check), not stale',
      (tester) async {
    final recent = DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
        .subtract(const Duration(hours: 2));
    final report = const SystemHealthReport().withRecord(
        Subsystem.healthSync, SubsystemHealth.unknown.withSuccess(recent));

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets(
      'a subsystem with no real cadence (weather) never reads stale, no matter '
      'how old its last success', (tester) async {
    final yearAgo = DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
        .subtract(const Duration(days: 365));
    final report = const SystemHealthReport()
        .withRecord(Subsystem.weather, SubsystemHealth.unknown.withSuccess(yearAgo));

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing,
        reason: 'weather has no periodic refresh at all -- there is no real '
            'schedule to compare against, so it must never show stale');
  });

  testWidgets('a real recorded failure shows red, not amber, even if also old',
      (tester) async {
    final longAgo = DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
        .subtract(const Duration(hours: 72));
    final report = const SystemHealthReport().withRecord(
        Subsystem.healthSync,
        SubsystemHealth.unknown
            .withSuccess(longAgo)
            .withFailure(DateTime.now(), 'boom')); // now-ok: see above

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing,
        reason: 'a real recorded failure is worse than merely stale and must win');
  });
}
