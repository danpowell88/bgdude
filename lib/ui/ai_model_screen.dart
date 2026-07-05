import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Download / manage the optional on-device Gemma model that normalises messy or
/// foreign-language nutrition-panel OCR into structured values. Everything runs on-device;
/// the model is fetched once from a URL you provide (Gemma is licence-gated, so we can't
/// ship a link) and can be removed any time. The deterministic parser works without it.
class AiModelScreen extends ConsumerStatefulWidget {
  const AiModelScreen({super.key});

  @override
  ConsumerState<AiModelScreen> createState() => _AiModelScreenState();
}

class _AiModelScreenState extends ConsumerState<AiModelScreen> {
  final _url = TextEditingController();
  final _token = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url.text = ref.read(panelModelProvider).url ?? '';
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final url = _url.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (url.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Paste the model .task URL first.')));
      return;
    }
    final token = _token.text.trim();
    try {
      await ref
          .read(panelModelProvider.notifier)
          .download(url, token: token.isEmpty ? null : token);
      messenger.showSnackBar(
          const SnackBar(content: Text('Model downloaded — AI parsing is on.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _delete() async {
    await ref.read(panelModelProvider.notifier).remove();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Model removed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(panelModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition-label AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'When you scan a nutrition label, the on-device OCR + parser handle standard '
            'layouts. This optional model (Gemma, ~0.5 GB) helps with unusual or '
            'foreign-language panels — it runs entirely on your phone and only when the '
            'parser needs it. Everything still works without it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                status.installed
                    ? Icons.check_circle
                    : Icons.download_for_offline_outlined,
                color: status.installed
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(status.installed
                  ? 'Model installed — AI parsing on'
                  : status.downloading
                      ? 'Downloading…'
                      : 'Not installed (parser-only)'),
              subtitle: status.downloading
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                          value: status.progress.clamp(0, 100) / 100.0),
                    )
                  : null,
              trailing: status.installed
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove model',
                      onPressed: status.downloading ? null : _delete,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            enabled: !status.downloading,
            decoration: const InputDecoration(
              labelText: 'Model URL (.task)',
              hintText: 'https://…/gemma3-1b-it-int4.task',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            enabled: !status.downloading,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Access token (optional)',
              helperText: 'For licence-gated hosts (e.g. a Hugging Face token)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: status.downloading ? null : _download,
            icon: const Icon(Icons.download),
            label: Text(status.installed ? 'Re-download' : 'Download model'),
          ),
          const SizedBox(height: 16),
          Text(
            'Gemma is licence-gated, so bgdude can\'t bundle or link the file. Accept '
            'Google\'s Gemma licence, grab a Gemma 3 1B .task model URL (e.g. the '
            'litert-community build on Hugging Face), and paste it above with an access '
            'token if the host requires one. It downloads once and stays on your device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
