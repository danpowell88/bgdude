import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// First-run onboarding. The critical screen is the pairing warning: pairing with
/// pumpx2 unpairs the official t:connect app (mutual exclusion), and pairing is a
/// reverse-engineered proof-of-concept that can be flaky. The user must acknowledge this
/// before proceeding.
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

  @override
  Widget build(BuildContext context) {
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
                  _page3(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_page + 1} / 3'),
                  FilledButton(
                    onPressed: _canAdvance ? _advance : null,
                    child: Text(_page == 2 ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canAdvance => _page != 1 || _acceptedPairing;

  void _advance() {
    if (_page == 2) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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

  Widget _page3(BuildContext context) => _pane(
        context,
        icon: Icons.health_and_safety,
        title: 'Connect your data',
        body:
            'Next you\'ll grant Health Connect access (sleep, HRV, resting heart rate, '
            'steps, workouts — your Garmin data flows in through Google Health) and pair '
            'your pump. The insight models stay neutral until they\'ve learned from a '
            'couple of weeks of your data.',
      );

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
