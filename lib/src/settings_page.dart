import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
  });

  final QuranAppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _syncKeyController;
  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isClearingCache = false;
  String _errorText = '';

  QuranAppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _syncKeyController = TextEditingController(text: controller.syncKey);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _syncKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = '';
    });
    final result = await controller.saveGeminiApiKey(_apiKeyController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _errorText = result ?? '';
    });
    if (result != null) {
      return;
    }
    _apiKeyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gemini API key saved on this device.')),
    );
  }

  Future<void> _deleteApiKey() async {
    await controller.deleteGeminiApiKey();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gemini API key removed.')),
    );
  }

  Future<void> _clearCache() async {
    setState(() {
      _isClearingCache = true;
    });
    await controller.clearAiCache();
    if (!mounted) {
      return;
    }
    setState(() {
      _isClearingCache = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved AI insights cleared.')),
    );
  }

  Future<void> _copySyncKey() async {
    final syncKey = _syncKeyController.text.trim();
    if (syncKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no sync key to copy yet.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: syncKey));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync key copied.')),
    );
  }

  Future<void> _syncProgress() async {
    FocusScope.of(context).unfocus();
    final result = await controller.syncProgress(_syncKeyController.text);
    if (!mounted) {
      return;
    }
    if (result == null) {
      _syncKeyController.text = controller.syncKey;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result ?? 'Progress and goal synced with this key.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final lastSyncAt = controller.lastSyncAt;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device sync',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use the same key on your other device, then tap Sync there to bring your Quran progress and goal together.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('sync-key-field'),
                          controller: _syncKeyController,
                          decoration: InputDecoration(
                            labelText: 'Sync key',
                            hintText: 'Paste or copy your sync key',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              key: const Key('copy-sync-key-button'),
                              onPressed: _copySyncKey,
                              icon: const Icon(Icons.copy_all_outlined),
                              tooltip: 'Copy sync key',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.isSyncAvailable
                              ? lastSyncAt == null
                                  ? 'This device has not synced yet.'
                                  : 'Last synced on this device: '
                                      '${lastSyncAt.year.toString().padLeft(4, '0')}-'
                                      '${lastSyncAt.month.toString().padLeft(2, '0')}-'
                                      '${lastSyncAt.day.toString().padLeft(2, '0')} '
                                      '${lastSyncAt.hour.toString().padLeft(2, '0')}:'
                                      '${lastSyncAt.minute.toString().padLeft(2, '0')}'
                              : controller.syncUnavailableReason ??
                                  'Sync is unavailable.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: controller.isSyncAvailable
                                ? null
                                : theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('sync-progress-button'),
                          onPressed:
                              controller.isSyncing ? null : _syncProgress,
                          icon: controller.isSyncing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_outlined),
                          label: const Text('Sync'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Word model: gemini-3-flash-preview\nAyah model: gemini-3-flash-preview',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          controller.hasGeminiApiKey
                              ? 'An API key is already saved on this device.'
                              : 'No Gemini API key is saved yet.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('gemini-api-key-field'),
                          controller: _apiKeyController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            labelText: 'Gemini API key',
                            hintText: 'Paste your API key',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              key:
                                  const Key('toggle-gemini-api-key-visibility'),
                              onPressed: () {
                                setState(() {
                                  _obscureApiKey = !_obscureApiKey;
                                });
                              },
                              icon: Icon(
                                _obscureApiKey
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (_errorText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorText,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              key: const Key('save-gemini-api-key-button'),
                              onPressed: _isSaving ? null : _saveApiKey,
                              icon: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save key'),
                            ),
                            if (controller.hasGeminiApiKey)
                              OutlinedButton.icon(
                                key: const Key('delete-gemini-api-key-button'),
                                onPressed: _deleteApiKey,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Remove key'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved AI insights',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Word analysis and ayah explanation responses are cached locally so repeated requests can open instantly.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('clear-ai-cache-button'),
                          onPressed: _isClearingCache ? null : _clearCache,
                          icon: _isClearingCache
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_outlined),
                          label: const Text('Clear saved insights'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
