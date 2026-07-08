/// TASK-195 AC#1: a repeatable chaos run — random cross-screen navigation, rotation,
/// and background/foreground churn against the live demo app — asserting nothing
/// escapes as an uncaught exception.
///
/// TASK-293: an earlier version of this file (TASK-257) tried to detect crashes via
/// the app's own `crash`-tagged log (main.dart's `_captureCrash`, wired through a
/// FlutterError.onError chained in the harness). That never worked: flutter_test's
/// `TestWidgetsFlutterBinding` installs its OWN `FlutterError.onError` for the
/// duration of the whole test body (restored only afterwards), so a handler installed
/// in `setUp` is always overridden the moment the test starts — the crash-tag
/// assertion was silently vacuous. The framework's own supported mechanism for this
/// is [WidgetTester.takeException] — checked after every step here so an early
/// exception can't be silently overwritten by a later one (the framework only holds
/// one pending exception at a time).
///
/// Run with: flutter test integration_test/chaos_navigation_test.dart -d <device-id>
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

/// How many random actions the chaos walk performs. Bounded (not "N minutes" of
/// wall-clock) so the run has a predictable, CI-friendly duration while still being
/// large enough to surface navigation races — ~150 actions covers many multiples of
/// every screen in the tab shell.
const _chaosSteps = 150;

/// Fixed seed: reproducible across runs so a regression can be re-triggered exactly,
/// per the ticket's "seeded for reproducibility" requirement.
const _seed = 20260706;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // TASK-220: KvStore is a process-global static, and this file runs a single
  // long-lived chaos walk per test rather than many short ones, but the reset still
  // guards against state leaking in FROM an earlier file in the same test process.
  setUp(setUpDemoHarness);

  testWidgets('chaos: $_chaosSteps random actions leave zero uncaught exceptions',
      (tester) async {
    await pumpDemoApp(tester);
    final rnd = Random(_seed);

    final tabIcons = [
      Icons.home_outlined,
      Icons.insights_outlined,
      Icons.lightbulb_outline,
      Icons.restaurant_outlined,
    ];

    Future<void> settleBounded() async {
      // pumpAndSettle() can hang forever against a persistently-animating widget
      // (e.g. a progress spinner mid-fetch) — bound it with a handful of timed
      // pumps instead, which is exactly what a chaos run needs to tolerate.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    for (var step = 0; step < _chaosSteps; step++) {
      // TASK-291: two real-device dispatches hung somewhere in this file with zero
      // further log output until the job's own 45-min timeout killed it -- this
      // periodic marker is the cheapest way to bisect which step it's stuck on from
      // a future run's log, since the loop itself has no other progress output.
      if (step % 25 == 0) {
        // ignore: avoid_print
        print('chaos walk: step $step/$_chaosSteps');
      }
      final action = rnd.nextInt(6);
      try {
        switch (action) {
          case 0: // Tap a random bottom tab.
            final icon = tabIcons[rnd.nextInt(tabIcons.length)];
            final finder = find.byIcon(icon);
            if (finder.evaluate().isNotEmpty) {
              await tester.tap(finder.first);
              await settleBounded();
            }
          case 1: // Open Settings.
            final gear = find.byIcon(Icons.settings_outlined);
            if (gear.evaluate().isNotEmpty) {
              await tester.tap(gear.first);
              await settleBounded();
            }
          case 2: // Back out of whatever screen is on top.
            final back = find.byTooltip('Back');
            if (back.evaluate().isNotEmpty) {
              await tester.tap(back.first);
              await settleBounded();
            } else {
              // No back target — a benign no-op step, not a chaos-run failure.
              await tester.pump(const Duration(milliseconds: 50));
            }
          case 3: // Rotate: portrait <-> landscape.
            final size = rnd.nextBool()
                ? const Size(1080, 2400)
                : const Size(2400, 1080);
            await tester.binding.setSurfaceSize(size);
            await settleBounded();
          case 4: // Background then foreground (app lifecycle churn).
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.paused);
            await tester.pump(const Duration(milliseconds: 50));
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            await settleBounded();
          case 5: // Tap a random on-screen tappable (whatever exists right now).
            final tappables = find.byType(InkWell);
            final n = tappables.evaluate().length;
            if (n > 0) {
              await tester.tap(tappables.at(rnd.nextInt(n)));
              await settleBounded();
            }
        }
      } catch (_) {
        // A widget-finder mismatch (e.g. tapped something that just navigated away)
        // is an expected hazard of a RANDOM walk, not the app crashing -- these never
        // reach the framework's own exception capture (below), which is the real
        // pass/fail signal.
      }

      // TASK-293: takeException() both retrieves AND clears the framework's single
      // pending-exception slot, so checking here (every step, not just at the end)
      // means an early build/layout/gesture exception can't be silently overwritten
      // by a later one, and the failure message pinpoints which step caused it.
      final exception = tester.takeException();
      if (exception != null) {
        fail('chaos walk step $step (action $action) triggered an uncaught '
            'exception:\n$exception');
      }
    }

    // Restore a normal size/lifecycle state so later tests in the same run aren't
    // affected by whatever the chaos walk left things in.
    await tester.binding.setSurfaceSize(null);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleBounded();

    final trailingException = tester.takeException();
    if (trailingException != null) {
      fail('chaos walk triggered an uncaught exception during final cleanup:\n'
          '$trailingException');
    }
  },
      // TASK-291: two real-device dispatches saw this file run to the surrounding
      // CI job's full 45-min timeout with zero progress -- bound it here instead so
      // a hang fails fast with a real TimeoutException/stack trace pointing at the
      // stuck step, rather than silently consuming the whole job's budget and every
      // other step that would have run after it.
      timeout: const Timeout(Duration(minutes: 10)));
}
