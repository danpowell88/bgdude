/// What the barcode scanner shows when the camera can't start (issue #376, gap 2).
///
/// The permissions audit found CAMERA was the one declared runtime permission with no
/// app-owned flow at all: `MobileScanner` was constructed with no `errorBuilder`, so a
/// denied camera left the user looking at the plugin's bare default with no rationale
/// for why bgdude wanted the camera and no route to fix it — unlike the BLE path,
/// which distinguishes plain denial from permanent denial and offers system settings.
///
/// Kept as its own widget rather than an inline closure so it is widget-testable
/// without instantiating `MobileScanner`, which needs a real camera platform.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerErrorView extends StatelessWidget {
  const ScannerErrorView({super.key, required this.errorCode, this.onOpenSettings});

  final MobileScannerErrorCode errorCode;

  /// Overridable so a test can assert the action fires without invoking the real
  /// `openAppSettings` platform channel.
  final VoidCallback? onOpenSettings;

  bool get _isPermissionDenied =>
      errorCode == MobileScannerErrorCode.permissionDenied;

  String get _message => switch (errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'bgdude needs the camera to read a product barcode. Nothing leaves the '
              'phone — only the barcode number is looked up, and only when barcode '
              'lookup is on.',
        MobileScannerErrorCode.unsupported =>
          'This device has no camera the scanner can use. You can still add foods '
              'by searching for them by name.',
        _ => 'The camera could not be started. You can still add foods by searching '
            'for them by name.',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPermissionDenied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
              size: 48,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _isPermissionDenied ? 'Camera access is off' : 'Camera unavailable',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(_message, textAlign: TextAlign.center),
            // Only a denial is actionable from system settings. Offering "Open
            // settings" for a device with no camera would send the user somewhere
            // that cannot help.
            if (_isPermissionDenied) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onOpenSettings ?? openAppSettings,
                child: const Text('Open settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
