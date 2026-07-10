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

Future<void> _pumpScreen(
  WidgetTester tester,
  SystemHealthReport report, {
  Map<String, dynamic>? garminHealth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        systemHealthProvider
            .overrideWith((ref) => _FixedHealthNotifier(report)),
        garminHealthProvider.overrideWith((ref) async => garminHealth),
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
    final longAgo =
        DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
            .subtract(const Duration(hours: 72));
    final report = const SystemHealthReport().withRecord(
        Subsystem.healthSync, SubsystemHealth.unknown.withSuccess(longAgo));

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget,
        reason:
            'healthSync has a real 48h cadence and hasn\'t succeeded in 72h '
            'with zero recorded failures -- this is exactly the silent-stall case '
            'the stale state exists to catch');
    expect(find.textContaining('no recent activity'), findsOneWidget);
    // A genuinely unhealthy row must still be distinguishable -- stale is not the
    // same icon/wording as a real recorded failure.
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('a recent success reads healthy (green check), not stale',
      (tester) async {
    final recent =
        DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
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
    final yearAgo =
        DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
            .subtract(const Duration(days: 365));
    final report = const SystemHealthReport().withRecord(
        Subsystem.weather, SubsystemHealth.unknown.withSuccess(yearAgo));

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing,
        reason: 'weather has no periodic refresh at all -- there is no real '
            'schedule to compare against, so it must never show stale');
  });

  testWidgets('a real recorded failure shows red, not amber, even if also old',
      (tester) async {
    final longAgo =
        DateTime.now() // now-ok: _SubsystemTile.build() reads the wall clock
            .subtract(const Duration(hours: 72));
    final report = const SystemHealthReport().withRecord(
        Subsystem.healthSync,
        SubsystemHealth.unknown
            .withSuccess(longAgo)
            .withFailure(DateTime.now(), 'boom')); // now-ok: see above

    await _pumpScreen(tester, report);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing,
        reason:
            'a real recorded failure is worse than merely stale and must win');
  });

  group('never-run reads as neutral/unknown, not healthy (TASK-266)', () {
    testWidgets(
        'a subsystem that has never been attempted shows the neutral icon, not '
        'a green check', (tester) async {
      // An empty report -> every Subsystem.values entry defaults to
      // SubsystemHealth.unknown (lastAttemptAt == null).
      await _pumpScreen(tester, const SystemHealthReport());

      expect(find.byIcon(Icons.help_outline), findsWidgets,
          reason: 'a fresh install has never run any subsystem yet -- none of '
              'them have earned a green check');
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.textContaining('Never run yet'), findsWidgets);
    });

    testWidgets(
        'once a subsystem succeeds, only THAT row turns green -- the rest stay '
        'neutral', (tester) async {
      final recent = DateTime.now(); // now-ok: build() reads the wall clock
      final report = const SystemHealthReport().withRecord(
          Subsystem.healthSync, SubsystemHealth.unknown.withSuccess(recent));

      await _pumpScreen(tester, report);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget,
          reason: 'exactly one subsystem (healthSync) has actually run');
      expect(find.byIcon(Icons.help_outline), findsWidgets,
          reason: 'the other Subsystem.values entries are still never-run');
    });

    // The _GarminTile's own title happens to read the same as the
    // Subsystem.garminDelivery _SubsystemTile's label ("Garmin watch delivery")
    // -- that row's SubsystemHealth entry is never populated (see
    // Subsystem.expectedCadence's doc comment), so it's always the FIRST match;
    // the real _GarminTile, further down past the Divider, is always the LAST.
    Finder garminTileCard(WidgetTester tester) => find.ancestor(
        of: find.text('Garmin watch delivery').last,
        matching: find.byType(Card));

    testWidgets(
        'Garmin "not available" (health == null, e.g. demo mode) shows the '
        'neutral icon, not a green check', (tester) async {
      await _pumpScreen(tester, const SystemHealthReport(), garminHealth: null);
      await tester.scrollUntilVisible(find.textContaining('Not available'), 250,
          scrollable: find.byType(Scrollable).first);

      expect(find.textContaining('Not available'), findsOneWidget);
      final garminTile = garminTileCard(tester);
      expect(
          find.descendant(
              of: garminTile, matching: find.byIcon(Icons.help_outline)),
          findsOneWidget);
      expect(
          find.descendant(
              of: garminTile,
              matching: find.byIcon(Icons.check_circle_outline)),
          findsNothing);
    });

    testWidgets(
        'Garmin "no send attempted yet this session" shows the neutral icon, '
        'not a green check', (tester) async {
      await _pumpScreen(tester, const SystemHealthReport(),
          garminHealth: const {
            'lastSuccessAtMs': null,
            'consecutiveFailures': 0
          });
      await tester.scrollUntilVisible(
          find.textContaining('No send attempted yet'), 250,
          scrollable: find.byType(Scrollable).first);

      expect(find.textContaining('No send attempted yet'), findsOneWidget);
      final garminTile = garminTileCard(tester);
      expect(
          find.descendant(
              of: garminTile, matching: find.byIcon(Icons.help_outline)),
          findsOneWidget);
      expect(
          find.descendant(
              of: garminTile,
              matching: find.byIcon(Icons.check_circle_outline)),
          findsNothing);
    });

    testWidgets(
        'Garmin with a real recorded failure and no success is still red, not '
        'neutral', (tester) async {
      await _pumpScreen(tester, const SystemHealthReport(),
          garminHealth: const {
            'lastSuccessAtMs': null,
            'consecutiveFailures': 3
          });
      await tester.scrollUntilVisible(
          find.textContaining('Never succeeded'), 250,
          scrollable: find.byType(Scrollable).first);

      final garminTile = garminTileCard(tester);
      expect(
          find.descendant(
              of: garminTile, matching: find.byIcon(Icons.error_outline)),
          findsOneWidget,
          reason: 'a real recorded failure is worse than "never run" and must '
              'still win');
      expect(
          find.descendant(
              of: garminTile, matching: find.byIcon(Icons.help_outline)),
          findsNothing);
    });
  });
}
