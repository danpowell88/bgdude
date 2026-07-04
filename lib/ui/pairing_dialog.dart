import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Prompts for the pairing code the pump shows on its "Pair Device" screen and submits
/// it to the native bridge. Shown automatically when the pump requests a code
/// (see [PumpPairingListener]). The pump uses either a 6-char (older Control-IQ
/// firmware) or 16-char (newer / Mobi, JPAKE) code.
class PairingDialog extends ConsumerStatefulWidget {
  const PairingDialog({super.key, required this.long});

  /// True for the 16-char code type.
  final bool long;

  static Future<void> show(BuildContext context, {required bool long}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PairingDialog(long: long),
      );

  @override
  ConsumerState<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends ConsumerState<PairingDialog> {
  final _controller = TextEditingController();

  int get _length => widget.long ? 16 : 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text.trim();
    final valid = code.length == _length;
    return AlertDialog(
      title: const Text('Pair with pump'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On the pump: Bluetooth Settings → Pair Device. Enter the '
            '$_length-character code it shows.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _length,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              UpperCaseFormatter(),
              LengthLimitingTextInputFormatter(_length),
            ],
            decoration: const InputDecoration(
              labelText: 'Pairing code',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Text(
            'Pairing here unpairs the official t:connect app.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid
              ? () {
                  ref
                      .read(pumpClientProvider)
                      .submitPairingCode(code, long: widget.long);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Pair'),
        ),
      ],
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Drop into a screen's build to auto-show the pairing dialog and surface pump errors.
/// Call [attach] once from a widget that has a Navigator in scope.
class PumpPairingListener {
  const PumpPairingListener._();

  static void attach(WidgetRef ref, BuildContext context) {
    ref.listen(pumpPairingRequestProvider, (_, next) {
      final type = next.valueOrNull;
      if (type == null) return;
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        PairingDialog.show(context, long: type == 'LONG_16CHAR');
      }
    });
    ref.listen(pumpErrorProvider, (_, next) {
      final msg = next.valueOrNull;
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pump: $msg')));
      }
    });
  }
}
