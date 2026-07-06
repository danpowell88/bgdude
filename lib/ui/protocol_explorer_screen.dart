import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pump/probe_event.dart';
import '../pump/pump_snapshot.dart';
import '../pump/pump_source.dart';
import '../state/providers.dart';

/// Protocol Explorer — a read-only, on-device console for probing the t:slim X2 BLE
/// protocol. It fires any `currentStatus` request the pump supports (including messages the
/// app doesn't otherwise surface — HomeScreenMirror, PumpFeatures, PumpSettings,
/// SecretMenu…) and shows the raw cargo bytes + pumpx2's decoded fields, so undocumented
/// fields can be discovered on a live pump.
///
/// Read-only by construction: the native layer refuses to send anything that isn't an
/// unsigned CURRENT_STATUS request that doesn't modify insulin delivery (see
/// `ProtocolProbe.buildSafeRequest`). Nothing here can affect insulin.
class ProtocolExplorerScreen extends ConsumerStatefulWidget {
  const ProtocolExplorerScreen({super.key});

  @override
  ConsumerState<ProtocolExplorerScreen> createState() =>
      _ProtocolExplorerScreenState();
}

class _ProtocolExplorerScreenState
    extends ConsumerState<ProtocolExplorerScreen> {
  /// Captured messages, newest first.
  final List<ProbeEvent> _log = [];
  ProviderSubscription<AsyncValue<ProbeEvent>>? _sub;

  /// Captured in initState so dispose() doesn't touch `ref` after the element unmounts.
  late final PumpSource _source;

  @override
  void initState() {
    super.initState();
    _source = ref.read(pumpClientProvider);
    // Turn the native firehose on while this screen is open, and mirror every captured
    // message into the log.
    _source.setProbeCapture(true);
    _sub = ref.listenManual(pumpProbeEventProvider, (prev, next) {
      final e = next.valueOrNull;
      if (e != null && mounted) setState(() => _log.insert(0, e));
    });
  }

  @override
  void dispose() {
    _sub?.close();
    // Best-effort: stop the firehose when leaving (uses the cached source, not `ref`).
    _source.setProbeCapture(false);
    super.dispose();
  }

  Future<void> _send(ProbeRequest req, {int? arg1, int? arg2}) async {
    final result =
        await _source.sendProbe(req.className, arg1: arg1, arg2: arg2);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(result ?? 'Sent ${req.className}'),
      backgroundColor: result == null ? null : Theme.of(context).colorScheme.error,
    ));
  }

  bool _sweeping = false;

  /// Fire every non-parametric read in sequence (read-only). Great for a first pass on a
  /// live pump — the log then holds one response per supported message.
  Future<void> _sweep() async {
    if (_sweeping) return;
    final reads = ProbeCatalogFlat.sweepable;
    setState(() => _sweeping = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sweeping ${reads.length} reads…')),
    );
    for (final req in reads) {
      if (!mounted) break;
      await _source.sendProbe(req.className);
      // Small gap so responses interleave in order and we don't flood the BLE queue.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) {
      setState(() => _sweeping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sweep complete — see Log')),
      );
    }
  }

  void _copyAll() {
    final text = _log.map((e) => e.toReport()).join(
        '\n──────────────────────────────────────\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_log.length} events to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Protocol Explorer'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Requests'),
            Tab(text: 'Log'),
          ]),
          actions: [
            IconButton(
              tooltip: 'Sweep all reads',
              icon: _sweeping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_circle_outline),
              onPressed: _sweeping ? null : _sweep,
            ),
            IconButton(
              tooltip: 'Copy log',
              icon: const Icon(Icons.copy_all),
              onPressed: _log.isEmpty ? null : _copyAll,
            ),
            IconButton(
              tooltip: 'Clear log',
              icon: const Icon(Icons.delete_outline),
              onPressed:
                  _log.isEmpty ? null : () => setState(() => _log.clear()),
            ),
          ],
        ),
        body: Column(
          children: [
            const _ReadOnlyBanner(),
            const _ConnectionStrip(),
            Expanded(
              child: TabBarView(children: [
                _RequestCatalog(onSend: _send),
                _LogView(log: _log),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Read-only. Only unsigned status requests are sent — the native layer '
              'blocks anything that could affect insulin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStrip extends ConsumerWidget {
  const _ConnectionStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(pumpConnectionProvider).valueOrNull;
    final stage = conn?.stage ?? PumpConnectionStage.idle;
    final connected = stage == PumpConnectionStage.connected;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 18,
            color: connected ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            connected
                ? 'Connected — ${conn?.pumpName ?? 'pump'}'
                : 'Not connected (${stage.name}) — pair on the Pump screen first',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RequestCatalog extends StatelessWidget {
  const _RequestCatalog({required this.onSend});

  final Future<void> Function(ProbeRequest req, {int? arg1, int? arg2}) onSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final group in ProbeCatalog.groups)
          _CatalogGroup(group: group, onSend: onSend),
      ],
    );
  }
}

class _CatalogGroup extends StatelessWidget {
  const _CatalogGroup({required this.group, required this.onSend});

  final ProbeRequestGroup group;
  final Future<void> Function(ProbeRequest req, {int? arg1, int? arg2}) onSend;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(group.title,
          style: Theme.of(context).textTheme.titleSmall),
      initiallyExpanded: group.title.contains('opportunit') ||
          group.title.contains('Unknown'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final req in group.requests)
          _RequestTile(req: req, onSend: onSend),
      ],
    );
  }
}

class _RequestTile extends StatefulWidget {
  const _RequestTile({required this.req, required this.onSend});

  final ProbeRequest req;
  final Future<void> Function(ProbeRequest req, {int? arg1, int? arg2}) onSend;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  final _a1 = TextEditingController();
  final _a2 = TextEditingController();

  @override
  void dispose() {
    _a1.dispose();
    _a2.dispose();
    super.dispose();
  }

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (widget.req.status) {
      ProbeStatus.surfaced => scheme.primary,
      ProbeStatus.opportunity => scheme.tertiary,
      ProbeStatus.experimental => scheme.error,
    };
  }

  String _statusLabel() => switch (widget.req.status) {
        ProbeStatus.surfaced => 'in app',
        ProbeStatus.opportunity => 'opportunity',
        ProbeStatus.experimental => 'unknown',
      };

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: _statusColor(context), shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(req.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(_statusLabel(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _statusColor(context),
                      )),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => widget.onSend(
                  req,
                  arg1: req.parametric ? int.tryParse(_a1.text) : null,
                  arg2: req.parametric ? int.tryParse(_a2.text) : null,
                ),
                child: const Text('Send'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Text('${req.className} · ${req.note}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (req.parametric)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _a1,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          isDense: true, labelText: req.params.first),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _a2,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          isDense: true, labelText: req.params.last),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.log});

  final List<ProbeEvent> log;

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No messages yet.\nSend a request, or wait for the pump to push a '
            'status update.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: log.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LogCard(event: log[i]),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.event});

  final ProbeEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = event.isTx;
    final t = event.time;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          tx ? Icons.north_east : Icons.south_west,
          color: tx ? scheme.outline : scheme.primary,
        ),
        title: Text(event.name,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$time · op ${event.opcode ?? '—'} · ${event.characteristic ?? '—'} · '
          '${event.cargoBytes} B',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: event.toReport()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied')),
            );
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(context, 'cargo (hex)',
                    event.cargoHex?.isNotEmpty == true ? event.cargoHex! : '(empty)'),
                if (event.json != null && event.json!.isNotEmpty)
                  _field(context, 'decoded', event.json!),
                if (event.verbose != null && event.verbose!.isNotEmpty)
                  _field(context, 'verbose', event.verbose!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 2),
            SelectableText(value,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, height: 1.35)),
          ],
        ),
      );
}
