import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/units.dart';
import '../onboarding/onboarding_gate.dart';
import '../profile/user_profile.dart';
import '../state/app_flags.dart';
import '../state/ble_permissions.dart';
import '../state/providers.dart';
import 'pairing_dialog.dart';
import 'profile_form.dart';

/// First-run onboarding. Two screens gate progress: the pairing warning (pairing with
/// pumpx2 unpairs the official t:connect app and is a flaky proof-of-concept), and the
/// final "Get connected" step, which will not let you finish until you have **either**
/// paired a pump **or** chosen demo mode. There is no other way into demo mode.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _acceptedPairing = false;
  UserProfile _draftProfile = const UserProfile();

  /// The user picked demo mode on the final step.
  bool _demoChosen = false;

  /// A pairing scan is in flight (waiting for the pump / code prompt).
  bool _pairing = false;

  /// A pump was already paired before onboarding (returning user) — the pair path is
  /// then pre-satisfied.
  bool _pumpEverPaired = false;

  static const _pageCount = 4;
  static const _gate = OnboardingGate(pageCount: _pageCount);

  @override
  void initState() {
    super.initState();
    AppFlags.load().then((flags) {
      if (!mounted) return;
      setState(() => _pumpEverPaired = flags.pumpPaired);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show the pairing-code dialog / pump errors during onboarding too, so the pair
    // path can complete here rather than only inside the main shell.
    PumpPairingListener.attach(ref, context);

    final devMode = ref.watch(devModeProvider);

    // Persist and latch a successful pairing so the gate stays satisfied even if the link
    // later drops mid-onboarding. Ignore demo mode: the simulator reports "connected" the
    // instant demo is chosen, and that must never be mistaken for a real paired pump.
    ref.listen(pumpConnectionProvider, (_, next) async {
      if (ref.read(devModeProvider)) return;
      if (next.valueOrNull?.isConnected ?? false) {
        if (!_pumpEverPaired && mounted) setState(() => _pumpEverPaired = true);
        await (await AppFlags.load()).setPumpPaired(true);
      }
    });

    // A real pump connection only counts outside demo mode (see above).
    final realConnected = !devMode &&
        (ref.watch(pumpConnectionProvider).valueOrNull?.isConnected ?? false);
    final pumpReady = _gate.pumpReady(
        realConnected: realConnected, pumpEverPaired: _pumpEverPaired);
    // The final step needs an explicit demo choice or a pump (paired now or already).
    final lastStepSatisfied =
        _gate.lastStepSatisfied(demoChosen: _demoChosen, pumpReady: pumpReady);
    final canAdvance = _gate.canAdvance(
      page: _page,
      acceptedPairing: _acceptedPairing,
      lastStepSatisfied: lastStepSatisfied,
    );
    // Demo is whatever the user explicitly chose — then we skip pump/health permissions.
    final demoOnly = _demoChosen;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _page1(context),
                  _pairingWarning(context),
                  _profilePage(context),
                  _connectGate(context, pumpReady: pumpReady),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_page + 1} / $_pageCount'),
                  FilledButton(
                    onPressed:
                        canAdvance ? () => _advance(demoOnly: demoOnly) : null,
                    child: Text(
                        _page == _pageCount - 1 ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _advance({bool demoOnly = false}) async {
    if (_page == _pageCount - 1) {
      // Persist whatever profile fields the user filled in (all optional).
      if (!_draftProfile.isEmpty) {
        await ref.read(userProfileProvider.notifier).save(_draftProfile);
      }
      // Notifications matter in both demo and real mode (alerts). The pump/health
      // permissions only matter when actually using hardware.
      await [Permission.notification].request();
      if (!demoOnly) {
        // TASK-226: SDK-gated (locationWhenInUse below API 31, the split Bluetooth
        // permissions at 31+) -- a denial here just means the pairing scan below
        // will show its own rationale, so the result isn't checked yet.
        await requestBlePermissions();
        // TASK-183: continuous monitoring — ask once for the battery-optimization
        // exemption so Doze doesn't throttle BLE delivery and the overnight
        // summary backstop. Android shows the system consent dialog.
        await Permission.ignoreBatteryOptimizations.request();
        try {
          await ref.read(healthSyncServiceProvider).requestPermissions();
        } catch (_) {}
      }
      widget.onDone();
      return;
    }
    await _controller.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Begin scanning for a pump. The code prompt is handled by [PumpPairingListener].
  Future<void> _startPairing() async {
    setState(() => _pairing = true);
    final messenger = ScaffoldMessenger.of(context);
    // Leaving demo (if it was picked) makes pumpClientProvider the real bridge.
    if (ref.read(devModeProvider)) {
      ref.read(devModeProvider.notifier).state = false;
      await (await AppFlags.load()).setDevMode(false);
    }
    if (mounted) setState(() => _demoChosen = false);
    await Permission.notification.request();
    // TASK-226: SDK-gated -- locationWhenInUse below API 31 (split bluetoothScan/
    // bluetoothConnect don't exist there and BLE scanning legally needs fine
    // location), the split permissions at 31+.
    final ble = await requestBlePermissions();
    if (!ble.granted) {
      if (mounted) {
        setState(() => _pairing = false);
        messenger.showSnackBar(bleDeniedSnackBar(ble));
      }
      return;
    }
    try {
      await ref.read(pumpClientProvider).startScan();
    } catch (_) {}
  }

  /// Choose demo mode — the only path into it, and undoable later from the header.
  Future<void> _chooseDemo() async {
    ref.read(devModeProvider.notifier).state = true;
    await (await AppFlags.load()).setDevMode(true);
    if (mounted) setState(() => _demoChosen = true);
  }

  Widget _profilePage(BuildContext context) {
    final unit = ref.watch(glucoseUnitProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Icon(Icons.person_outline,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('About you', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Optional — a few details help tailor the insights. You can change these '
            'any time in Settings.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          // Glucose units — asked up front so every reading in the app shows the way
          // the user thinks about their numbers. Defaults to mmol/L (Australia).
          Row(
            children: [
              const Expanded(child: Text('Glucose units')),
              SegmentedButton<GlucoseUnit>(
                segments: const [
                  ButtonSegment(value: GlucoseUnit.mmol, label: Text('mmol/L')),
                  ButtonSegment(value: GlucoseUnit.mgdl, label: Text('mg/dL')),
                ],
                selected: {unit},
                onSelectionChanged: (s) =>
                    ref.read(glucoseUnitProvider.notifier).set(s.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProfileForm(
            initial: _draftProfile,
            onChanged: (p) => _draftProfile = p,
          ),
        ],
      ),
    );
  }

  Widget _page1(BuildContext context) => _pane(
        context,
        icon: Icons.insights,
        title: 'A personal companion for your t:slim X2',
        body:
            'bgdude reads your pump and CGM, pulls in sleep/HRV/exercise from Health '
            'Connect, and gives you dosing suggestions and daily insight — all on your '
            'phone. It reads only; you always dose on the pump yourself.',
      );

  Widget _pairingWarning(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Before you pair',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('• Pairing bgdude with your pump will unpair the official '
                't:connect app. You can only pair one at a time.'),
            const SizedBox(height: 8),
            const Text('• This uses a reverse-engineered connection (pumpx2). Pairing '
                'can be finicky — a retry, app restart, or re-pair sometimes helps.'),
            const SizedBox(height: 8),
            const Text('• bgdude never sends insulin or control commands. It cannot '
                'change your delivery.'),
            const Spacer(),
            CheckboxListTile(
              value: _acceptedPairing,
              onChanged: (v) => setState(() => _acceptedPairing = v ?? false),
              title: const Text('I understand and want to continue'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      );

  /// The final gate: pair a pump or enter demo mode. Finishing is blocked until one of
  /// these is done (enforced by [canAdvance] in [build]).
  Widget _connectGate(BuildContext context, {required bool pumpReady}) {
    final theme = Theme.of(context);
    // The pump path is "selected" only when a real pump is ready AND the user hasn't
    // chosen demo — so the two cards are mutually exclusive on the explicit choice.
    final pumpSelected = pumpReady && !_demoChosen;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Icon(Icons.cable, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Get connected', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'To continue, either pair your pump or explore with demo data. You can leave '
            'demo mode any time from the header once you\'re ready to pair.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // --- Pair a pump ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.bluetooth, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Pair your pump', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (pumpSelected)
                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    pumpSelected
                        ? 'Pump connected. You\'re ready to go.'
                        : _pairing
                            ? 'Scanning… put your pump on its Bluetooth pairing screen '
                                'and enter the code when prompted.'
                            : 'Connect your t:slim X2 over Bluetooth for live data.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: pumpSelected ? null : _startPairing,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: Text(_pairing && !pumpSelected
                        ? 'Scanning…'
                        : 'Pair your pump'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Demo mode ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.science_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Explore in demo mode',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (_demoChosen)
                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Run against a simulated t:slim X2 + Dexcom so you can see the whole '
                    'app — timeline, predictions, insights — without hardware.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _demoChosen ? null : _chooseDemo,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(_demoChosen
                        ? 'Demo mode selected'
                        : 'Use demo mode'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pane(BuildContext context,
          {required IconData icon,
          required String title,
          required String body}) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
