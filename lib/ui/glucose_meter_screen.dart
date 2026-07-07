import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../integrations/glucose_meter_controller.dart';
import '../integrations/glucose_meter_transport.dart';
import '../state/providers.dart';

/// Pair, manage and sync a Bluetooth glucose meter (standard GLS — e.g. Accu-Chek Guide
/// Me). Imported fingersticks are stored as calibration-type readings in history.
class GlucoseMeterScreen extends ConsumerStatefulWidget {
  const GlucoseMeterScreen({super.key});

  @override
  ConsumerState<GlucoseMeterScreen> createState() => _GlucoseMeterScreenState();
}

class _GlucoseMeterScreenState extends ConsumerState<GlucoseMeterScreen> {
  StreamSubscription<MeterDevice>? _scanSub;
  final _found = <MeterDevice>[];
  bool _scanning = false;

  // TASK-209: `ref` throws "Cannot use ref after the widget was disposed" the moment
  // `dispose()` runs (riverpod marks it unusable as soon as the element goes inactive,
  // before `State.dispose()` is even called) — cache the transport in initState so
  // dispose() never needs `ref`. Reading it in dispose() was also unconditionally
  // throwing before `super.dispose()` could run, so cleanup silently never completed.
  late final GlucoseMeterTransport _transport;

  @override
  void initState() {
    super.initState();
    _transport = ref.read(glucoseMeterTransportProvider);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _transport.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    final transport = _transport;
    final messenger = ScaffoldMessenger.of(context);
    if (!await transport.isAvailable()) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Turn on Bluetooth to scan for your meter.')));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _found.clear();
      _scanning = true;
    });
    await _scanSub?.cancel();
    _scanSub = transport.scan().listen(
      (d) {
        if (!mounted) return;
        setState(() {
          if (!_found.any((e) => e.id == d.id)) _found.add(d);
        });
      },
      onError: (Object e) {
        if (mounted) setState(() => _scanning = false);
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _pair(MeterDevice d) async {
    await _scanSub?.cancel();
    setState(() => _scanning = false);
    await ref.read(glucoseMeterProvider.notifier).pair(d);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(glucoseMeterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Glucose meter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Import fingersticks from a Bluetooth glucose meter (e.g. Accu-Chek Guide Me). '
            'They\'re saved as calibration-type readings — separate from your CGM.',
          ),
          const SizedBox(height: 16),
          if (status.isPaired) ..._pairedView(status) else ..._pairView(),
        ],
      ),
    );
  }

  List<Widget> _pairedView(GlucoseMeterStatus status) {
    final meter = status.paired!;
    return [
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.bloodtype_outlined),
              title: Text(meter.name),
              subtitle: Text(status.lastSyncAt == null
                  ? 'Not synced yet'
                  : 'Last synced ${_ago(status.lastSyncAt!)} · '
                      '${status.totalImported} imported'),
            ),
            if (status.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(status.error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.link_off),
                  label: const Text('Unpair'),
                  onPressed: status.syncing
                      ? null
                      : () => ref.read(glucoseMeterProvider.notifier).unpair(),
                ),
                FilledButton.icon(
                  icon: status.syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: Text(status.syncing ? 'Syncing…' : 'Sync now'),
                  onPressed: status.syncing
                      ? null
                      : () => ref.read(glucoseMeterProvider.notifier).syncNow(),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text('Recent fingersticks',
          style: Theme.of(context).textTheme.titleMedium),
      ..._recentFingersticks(),
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'The meter\'s own clock sets each reading\'s time; if it drifts from your phone, '
          'imported times can be slightly off.',
          style: TextStyle(fontSize: 13),
        ),
      ),
    ];
  }

  List<Widget> _recentFingersticks() {
    final unit = ref.watch(glucoseUnitProvider);
    // In demo mode show representative rows (no hardware to import from).
    final demoRows = ref.watch(devModeProvider)
        ? <({DateTime time, double mgdl})>[
            (time: DateTime.now().subtract(const Duration(hours: 3)), mgdl: 142),
            (time: DateTime.now().subtract(const Duration(hours: 9)), mgdl: 68),
            (time: DateTime.now().subtract(const Duration(hours: 21)), mgdl: 96),
          ]
        : const <({DateTime time, double mgdl})>[];
    if (demoRows.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Imported readings will appear here after a sync.',
              style: TextStyle(fontSize: 13)),
        ),
      ];
    }
    return [
      for (final r in demoRows)
        ListTile(
          dense: true,
          leading: const Icon(Icons.water_drop_outlined, size: 20),
          title: Text('${Mgdl(r.mgdl).display(unit)} ${unit.label}'),
          subtitle: Text(_ago(r.time)),
        ),
    ];
  }

  List<Widget> _pairView() {
    return [
      Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Put your meter into Bluetooth pairing mode (usually after a reading or by '
            'holding its button), then scan and pick it below. You\'ll confirm the pairing '
            'on the meter.',
          ),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        icon: _scanning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.bluetooth_searching),
        label: Text(_scanning ? 'Scanning…' : 'Scan for meter'),
        onPressed: _scanning ? null : _startScan,
      ),
      const SizedBox(height: 8),
      for (final d in _found)
        ListTile(
          leading: const Icon(Icons.bloodtype_outlined),
          title: Text(d.name),
          subtitle: Text(d.id),
          trailing: const Icon(Icons.add_link),
          onTap: () => _pair(d),
        ),
      if (_scanning && _found.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Looking for meters in pairing mode…',
              style: TextStyle(fontSize: 13)),
        ),
    ];
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
