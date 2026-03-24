import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_models.dart';
import 'app_controller.dart';
import 'settings_page.dart';

Future<void> showWordInsightDialog({
  required BuildContext context,
  required QuranAppController controller,
  required WordInsightRequest request,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _WordInsightDialog(
        controller: controller,
        request: request,
      );
    },
  );
}

Future<void> showAyahInsightDialog({
  required BuildContext context,
  required QuranAppController controller,
  required AyahInsightRequest request,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _AyahInsightDialog(
        controller: controller,
        request: request,
      );
    },
  );
}

class _WordInsightDialog extends StatefulWidget {
  const _WordInsightDialog({
    required this.controller,
    required this.request,
  });

  final QuranAppController controller;
  final WordInsightRequest request;

  @override
  State<_WordInsightDialog> createState() => _WordInsightDialogState();
}

class _WordInsightDialogState extends State<_WordInsightDialog> {
  WordInsightRecord? _record;
  bool _isFromCache = false;
  bool _isLoading = true;
  bool _needsApiKey = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _needsApiKey = false;
      _errorText = '';
    });
    try {
      final result = await widget.controller.getWordInsight(
        request: widget.request,
        refresh: refresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _record = result.data;
        _isFromCache = result.isFromCache;
      });
    } on MissingGeminiApiKeyException {
      if (!mounted) {
        return;
      }
      setState(() {
        _needsApiKey = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(controller: widget.controller),
      ),
    );
    if (!mounted || !widget.controller.hasGeminiApiKey) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return AlertDialog(
      title: const Text('Word insight'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: _InsightBody(
            isLoading: _isLoading,
            needsApiKey: _needsApiKey,
            errorText: _errorText,
            onOpenSettings: _openSettings,
            onRetry: _load,
            child: record == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetaRow(
                        isFromCache: _isFromCache,
                        generatedAt: record.generatedAt,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        record.word,
                        textDirection: TextDirection.rtl,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      _InsightSection(
                        title: 'বাংলা অর্থ',
                        body: record.insight.bengaliMeaning,
                      ),
                      _InsightSection(
                        title: 'প্রসঙ্গভিত্তিক অর্থ',
                        body: record.insight.contextualMeaning,
                      ),
                      _InsightSection(
                        title: 'ধাতু / Root',
                        body: record.insight.root,
                      ),
                      _InsightSection(
                        title: 'মাসদার',
                        body: record.insight.masdar,
                      ),
                      _InsightSection(
                        title: 'পদের ধরন',
                        body: record.insight.partOfSpeech,
                      ),
                      _InsightSection(
                        title: 'ভাষাগত নোট',
                        body: record.insight.linguisticNotes,
                      ),
                      _InsightSection(
                        title: 'নিশ্চয়তার নোট',
                        body: record.insight.confidenceNote,
                      ),
                    ],
                  ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (widget.controller.hasGeminiApiKey)
          FilledButton.icon(
            key: const Key('refresh-word-insight-button'),
            onPressed: _isLoading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
      ],
    );
  }
}

class _AyahInsightDialog extends StatefulWidget {
  const _AyahInsightDialog({
    required this.controller,
    required this.request,
  });

  final QuranAppController controller;
  final AyahInsightRequest request;

  @override
  State<_AyahInsightDialog> createState() => _AyahInsightDialogState();
}

class _AyahInsightDialogState extends State<_AyahInsightDialog> {
  AyahInsightRecord? _record;
  bool _isFromCache = false;
  bool _isLoading = true;
  bool _needsApiKey = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _needsApiKey = false;
      _errorText = '';
    });
    try {
      final result = await widget.controller.getAyahInsight(
        request: widget.request,
        refresh: refresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _record = result.data;
        _isFromCache = result.isFromCache;
      });
    } on MissingGeminiApiKeyException {
      if (!mounted) {
        return;
      }
      setState(() {
        _needsApiKey = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(controller: widget.controller),
      ),
    );
    if (!mounted || !widget.controller.hasGeminiApiKey) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return AlertDialog(
      title: const Text('Ayah insight'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: _InsightBody(
            isLoading: _isLoading,
            needsApiKey: _needsApiKey,
            errorText: _errorText,
            onOpenSettings: _openSettings,
            onRetry: _load,
            child: record == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetaRow(
                        isFromCache: _isFromCache,
                        generatedAt: record.generatedAt,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.request.ayahText,
                        textDirection: TextDirection.rtl,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              height: 1.7,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _InsightSection(
                        title: 'বাংলা অর্থ',
                        body: record.insight.bengaliMeaning,
                      ),
                      _InsightSection(
                        title: 'তাফসিরভিত্তিক ব্যাখ্যা',
                        body: record.insight.tafsirSummary,
                      ),
                      _InsightSection(
                        title: 'মূল থিম',
                        body: record.insight.keyThemes,
                      ),
                      _InsightSection(
                        title: 'আমলের শিক্ষা',
                        body: record.insight.practicalLessons,
                      ),
                      if (record.insight.sources.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Sources',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final source in record.insight.sources)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(source.title),
                            subtitle: Text(source.url),
                            trailing:
                                const Icon(Icons.open_in_new_rounded, size: 18),
                            onTap: () async {
                              await launchUrl(
                                Uri.parse(source.url),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (widget.controller.hasGeminiApiKey)
          FilledButton.icon(
            key: const Key('refresh-ayah-insight-button'),
            onPressed: _isLoading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
      ],
    );
  }
}

class _InsightBody extends StatelessWidget {
  const _InsightBody({
    required this.isLoading,
    required this.needsApiKey,
    required this.errorText,
    required this.onOpenSettings,
    required this.onRetry,
    required this.child,
  });

  final bool isLoading;
  final bool needsApiKey;
  final String errorText;
  final VoidCallback onOpenSettings;
  final Future<void> Function({bool refresh}) onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (isLoading && child == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (needsApiKey) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Save a Gemini API key in Settings to use this feature.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('open-settings-from-insight-dialog-button'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open settings'),
          ),
        ],
      );
    }

    if (errorText.isNotEmpty && child == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(errorText),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (child != null) child!,
        if (errorText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            errorText,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (isLoading && child != null) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.isFromCache,
    required this.generatedAt,
  });

  final bool isFromCache;
  final DateTime generatedAt;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text(isFromCache ? 'Saved response' : 'Fresh response'),
        ),
        Chip(
          label: Text(_formatTimestamp(generatedAt)),
        ),
      ],
    );
  }
}

String _formatTimestamp(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
