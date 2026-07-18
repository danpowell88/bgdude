import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'widgets/scanner_error_view.dart';

/// Full-screen barcode scanner. Pops the first detected barcode value (or null if the
/// user backs out). The camera stays on-device — only the resulting code is looked up,
/// and only when barcode lookup is enabled.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Issue #376: without this the user gets the plugin's bare default on a
            // denied camera — no reason bgdude wanted it, no way to fix it.
            errorBuilder: (context, error) =>
                ScannerErrorView(errorCode: error.errorCode),
          ),
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 240,
                height: 140,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                        BorderSide(color: Colors.white70, width: 2)),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Text('Point at a product barcode',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
