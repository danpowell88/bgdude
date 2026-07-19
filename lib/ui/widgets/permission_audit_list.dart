/// Renders a permission audit (issue #376). Split from the screen so the copy and the
/// "what counts as a problem" logic can be tested without a device or plugins.
library;

import 'package:flutter/material.dart';

import '../../state/permission_audit.dart';

class PermissionAuditList extends StatelessWidget {
  const PermissionAuditList({
    super.key,
    required this.audit,
    required this.onFix,
  });

  final List<AuditedPermission> audit;
  final void Function(AppPermission) onFix;

  @override
  Widget build(BuildContext context) {
    final gaps = criticalGaps(audit);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (gaps.isNotEmpty)
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: cs.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gaps.length == 1
                          ? '${gaps.single.permission.title} is missing. '
                              '${gaps.single.permission.whatBreaks}'
                          : '${gaps.length} required permissions are missing — '
                              'alarms and pump monitoring may not work.',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final a in audit) _Tile(audited: a, onFix: onFix),
        const SizedBox(height: 8),
        Text(
          'bgdude never uses your location. Location appears here only because '
          'Android 11 and below require it to scan for any Bluetooth device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.audited, required this.onFix});

  final AuditedPermission audited;
  final void Function(AppPermission) onFix;

  @override
  Widget build(BuildContext context) {
    final p = audited.permission;
    final cs = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (audited.grant) {
      PermissionGrant.granted => (Icons.check_circle, cs.primary, 'Granted'),
      PermissionGrant.denied => (Icons.cancel, cs.error, 'Not granted'),
      PermissionGrant.permanentlyDenied => (
          Icons.block,
          cs.error,
          'Denied — needs system settings'
        ),
      PermissionGrant.unknown => (
          Icons.help_outline,
          cs.outline,
          "Can't tell from here"
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(p.title,
                      style: Theme.of(context).textTheme.titleSmall)),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(p.why, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            // The consequence, not just the request — this is the half that tells the
            // user whether to care.
            Text('Without it: ${p.whatBreaks}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            Text('Asked for: ${p.requestedAt}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.outline)),
            if (audited.grant == PermissionGrant.denied ||
                audited.grant == PermissionGrant.permanentlyDenied)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onFix(p),
                  child: const Text('Open settings'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
