import 'package:flutter/material.dart';

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
  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isClearingCache = false;
  String _errorText = '';

  QuranAppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
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
                              key: const Key('toggle-gemini-api-key-visibility'),
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
