import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/widgets/event_marker_bar.dart';
import 'package:bgdude/ui/widgets/on_board_forecast_chart.dart';
import 'package:bgdude/ui/widgets/prediction_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/faults.dart';

// TASK-261: medicationModeProvider's notifier now reads notificationServiceProvider
// at construction (to notify on auto-expiry) -- effectiveSensitivityProvider watches
// medicationModeProvider, which these charts read transitively, so
// notificationServiceProvider (throw-by-default outside main()) must be overridden
// here too even though these tests never trigger a notification themselves.
Widget _host(Widget child, {DateTime? fixedNow}) => ProviderScope(
      overrides: [
        devModeProvider.overrideWith((ref) => true),
        notificationServiceProvider
            .overrideWithValue(NoopNotificationService()),
        if (fixedNow != null)
          demoClockProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// Finds any [EventMarkerBar] marker icon, regardless of its event id.
final _anyEventMarker = find.byWidgetPredicate((w) =>
    w.key is ValueKey<String> &&
    (w.key as ValueKey<String>).value.startsWith('event-marker-'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('prediction chart + legend render with a glucose unit axis',
      (tester) async {
    await tester.pumpWidget(_host(
      const Column(children: [
        SizedBox(height: 200, child: PredictionChart(showScenarios: true)),
        PredictionChartLegend(scenarios: true),
      ]),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // The y-axis unit label + the scenario legend entries are present.
    expect(find.text('mmol/L'), findsWidgets); // default display unit
    expect(find.textContaining('Predicted'), findsWidgets);
    expect(find.textContaining('IOB'), findsWidgets);
    expect(find.textContaining('Zero-temp'), findsWidgets);
  });

  testWidgets(
      'prediction chart overlays an event marker and tapping it opens '
      'Explain this reading', (tester) async {
    // TASK-155: with the clock fixed just after the simulated day's nocturnal
    // compression low (~03:10, see sim_data.dart), that event lands ~50 min
    // before "now" -- inside PredictionChart's -150..0 min history window --
    // so a marker is guaranteed to render deterministically.
    final fixedNow = DateTime(2026, 7, 10, 4, 0);
    await tester.pumpWidget(_host(
      const SizedBox(height: 200, child: PredictionChart()),
      fixedNow: fixedNow,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(_anyEventMarker, findsWidgets);

    await tester.tap(_anyEventMarker.first);
    await tester.pumpAndSettle();

    expect(find.text('Explain this reading'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('on-board forecast chart renders with IOB/COB/basal legend',
      (tester) async {
    await tester.pumpWidget(_host(
      const Column(children: [
        OnBoardForecastChart(),
        OnBoardForecastLegend(),
      ]),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('IOB (U)'), findsOneWidget);
    expect(find.text('COB (g)'), findsOneWidget);
    expect(find.text('Basal (U/h)'), findsOneWidget);
  });
}
