import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'ai_dialogs.dart';
import 'ai_models.dart';
import 'app_controller.dart';
import 'models.dart';

class SurahReaderPage extends StatefulWidget {
  const SurahReaderPage({
    super.key,
    required this.controller,
    required this.surahIndex,
    this.initialAyahNumber,
  });

  final QuranAppController controller;
  final int surahIndex;
  final int? initialAyahNumber;

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  bool _isFullscreen = false;
  final ScrollController _readerScrollController = ScrollController();
  final Map<int, GlobalKey> _ayahAnchorKeys = <int, GlobalKey>{};
  double _pendingReaderOffset = 0;
  bool _hasAppliedInitialAyahJump = false;
  int _initialAyahJumpAttempts = 0;

  QuranAppController get controller => widget.controller;

  GlobalKey _anchorKeyForAyah(int ayahNumber) {
    return _ayahAnchorKeys.putIfAbsent(ayahNumber, GlobalKey.new);
  }

  @override
  void initState() {
    super.initState();
    _scheduleInitialAyahJumpIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SurahReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahIndex != widget.surahIndex ||
        oldWidget.initialAyahNumber != widget.initialAyahNumber) {
      _hasAppliedInitialAyahJump = false;
      _initialAyahJumpAttempts = 0;
      _scheduleInitialAyahJumpIfNeeded();
    }
  }

  Future<void> _scrollToAyah(int ayahNumber) async {
    final ayahContext = _anchorKeyForAyah(ayahNumber).currentContext;
    if (ayahContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      ayahContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  void _scheduleInitialAyahJumpIfNeeded() {
    final initialAyahNumber = widget.initialAyahNumber;
    if (initialAyahNumber == null ||
        initialAyahNumber < 1 ||
        _hasAppliedInitialAyahJump) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _hasAppliedInitialAyahJump) {
        return;
      }

      final ayahContext = _anchorKeyForAyah(initialAyahNumber).currentContext;
      if (ayahContext == null) {
        if (_initialAyahJumpAttempts >= 4) {
          return;
        }
        _initialAyahJumpAttempts += 1;
        _scheduleInitialAyahJumpIfNeeded();
        return;
      }

      _hasAppliedInitialAyahJump = true;
      await _scrollToAyah(initialAyahNumber);
    });
  }

  @override
  void dispose() {
    _readerScrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _setFullscreen(bool value) async {
    if (_isFullscreen == value) {
      return;
    }

    if (_readerScrollController.hasClients) {
      _pendingReaderOffset = _readerScrollController.offset;
    }

    setState(() {
      _isFullscreen = value;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_readerScrollController.hasClients) {
        return;
      }
      final position = _readerScrollController.position;
      final targetOffset = _pendingReaderOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _readerScrollController.jumpTo(targetOffset);
    });

    final palette = _paletteFor(controller.readerSettings.backgroundKey);
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(
        palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      );
      return;
    }

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  Future<void> _showReaderSettingsDialog() async {
    var selectedFontSize = controller.readerSettings.fontSize;
    var selectedBackgroundKey = controller.readerSettings.backgroundKey;
    var selectedTajweedEnabled = controller.readerSettings.tajweedEnabled;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reader settings'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Font size',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        key: const Key('reader-font-size-slider'),
                        min: ReaderSettings.minFontSize,
                        max: ReaderSettings.maxFontSize,
                        divisions: (ReaderSettings.maxFontSize -
                                ReaderSettings.minFontSize)
                            .round(),
                        value: selectedFontSize,
                        label: selectedFontSize.toStringAsFixed(0),
                        onChanged: (value) {
                          setState(() {
                            selectedFontSize = value;
                          });
                        },
                      ),
                      Center(
                        child: Text(
                          '${selectedFontSize.toStringAsFixed(0)} pt',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Reader background',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final palette in _readerPalettes)
                            _BackgroundChoice(
                              key: Key(
                                'reader-background-${palette.keyName}',
                              ),
                              palette: palette,
                              isSelected:
                                  selectedBackgroundKey == palette.keyName,
                              onTap: () {
                                setState(() {
                                  selectedBackgroundKey = palette.keyName;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SwitchListTile.adaptive(
                        key: const Key('reader-tajweed-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tajweed colors'),
                        subtitle: const Text(
                          'Show color-coded tajweed rules in the Quran text.',
                        ),
                        value: selectedTajweedEnabled,
                        onChanged: (value) {
                          setState(() {
                            selectedTajweedEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('save-reader-settings-button'),
                  onPressed: () async {
                    await controller.setReaderFontSize(selectedFontSize);
                    await controller.setReaderBackgroundKey(
                      selectedBackgroundKey,
                    );
                    await controller.setReaderTajweedEnabled(
                      selectedTajweedEnabled,
                    );
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }

    final palette = _paletteFor(controller.readerSettings.backgroundKey);
    SystemChrome.setSystemUIOverlayStyle(
      palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  Future<void> _navigateToAdjacentSurah(int surahOffset) async {
    final targetSurah =
        controller.trySurahByIndex(widget.surahIndex + surahOffset);
    if (targetSurah == null || !mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SurahReaderPage(
          controller: controller,
          surahIndex: targetSurah.index,
        ),
      ),
    );
  }

  Future<void> _handleHorizontalDragEnd(DragEndDetails details) async {
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    if (velocity.abs() < 250) {
      return;
    }

    if (velocity > 0) {
      await _navigateToAdjacentSurah(1);
      return;
    }

    await _navigateToAdjacentSurah(-1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final surah = controller.surahByIndex(widget.surahIndex);
        final settings = controller.readerSettings;
        final palette = _paletteFor(settings.backgroundKey);
        final percent = controller.percentForSurah(surah);
        final savedRanges = controller.rangesFor(surah.index);

        return PopScope(
          canPop: !_isFullscreen,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !_isFullscreen) {
              return;
            }
            await _setFullscreen(false);
          },
          child: Scaffold(
            backgroundColor: palette.scaffoldColor,
            appBar: _isFullscreen
                ? null
                : AppBar(
                    backgroundColor: palette.scaffoldColor,
                    foregroundColor: palette.toolbarColor,
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(surah.englishName),
                        Text(
                          surah.arabicName,
                          textDirection: TextDirection.rtl,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontFamily: 'UthmanicHafs',
                                    fontSize: 24,
                                    color: palette.toolbarColor,
                                  ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        key: const Key('reader-settings-button'),
                        onPressed: _showReaderSettingsDialog,
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Reader settings',
                      ),
                      IconButton(
                        key: const Key('reader-fullscreen-button'),
                        onPressed: () => _setFullscreen(true),
                        icon: const Icon(Icons.fullscreen_rounded),
                        tooltip: 'Full screen',
                      ),
                    ],
                  ),
            body: GestureDetector(
              key: const Key('reader-swipe-area'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: Stack(
                children: [
                  SafeArea(
                    top: !_isFullscreen,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _isFullscreen ? 8 : 20,
                        _isFullscreen ? 8 : 8,
                        _isFullscreen ? 8 : 20,
                        _isFullscreen ? 8 : 20,
                      ),
                      child: _ReaderLayout(
                        surah: surah,
                        controller: controller,
                        percent: percent,
                        savedRanges: savedRanges,
                        onRangeTap: (range) => _scrollToAyah(range.toAyah),
                        palette: palette,
                        fontSize: settings.fontSize,
                        isFullscreen: _isFullscreen,
                        scrollController: _readerScrollController,
                        ayahAnchorKeyFor: _anchorKeyForAyah,
                      ),
                    ),
                  ),
                  if (_isFullscreen)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _FullscreenToolbar(
                          surah: surah,
                          palette: palette,
                          onBack: () => Navigator.of(context).maybePop(),
                          onSettings: _showReaderSettingsDialog,
                          onExitFullscreen: () => _setFullscreen(false),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderLayout extends StatelessWidget {
  const _ReaderLayout({
    required this.surah,
    required this.controller,
    required this.percent,
    required this.savedRanges,
    required this.onRangeTap,
    required this.palette,
    required this.fontSize,
    required this.isFullscreen,
    required this.scrollController,
    required this.ayahAnchorKeyFor,
  });

  final SurahData surah;
  final QuranAppController controller;
  final double percent;
  final List<AyahRange> savedRanges;
  final ValueChanged<AyahRange> onRangeTap;
  final _ReaderPalette palette;
  final double fontSize;
  final bool isFullscreen;
  final ScrollController scrollController;
  final GlobalKey Function(int ayahNumber) ayahAnchorKeyFor;

  @override
  Widget build(BuildContext context) {
    if (isFullscreen) {
      return _ReaderCanvas(
        surah: surah,
        controller: controller,
        palette: palette,
        fontSize: fontSize,
        isFullscreen: true,
        scrollController: scrollController,
        ayahAnchorKeyFor: ayahAnchorKeyFor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const Key('reader-progress-card'),
          decoration: BoxDecoration(
            color: palette.surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap any ayah to save your progress.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.textColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Read progress: ${formatPercent(percent)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.secondaryTextColor,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: savedRanges.isEmpty
                      ? [
                          const Chip(
                            label: Text('No saved ranges yet'),
                          ),
                        ]
                      : savedRanges
                          .map<Widget>(
                            (range) => ActionChip(
                              key: Key(
                                'range-chip-${range.fromAyah}-${range.toAyah}',
                              ),
                              label: Text(
                                'Ayah ${range.fromAyah} to ${range.toAyah}',
                              ),
                              onPressed: () => onRangeTap(range),
                            ),
                          )
                          .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _ReaderCanvas(
            surah: surah,
            controller: controller,
            palette: palette,
            fontSize: fontSize,
            isFullscreen: false,
            scrollController: scrollController,
            ayahAnchorKeyFor: ayahAnchorKeyFor,
          ),
        ),
      ],
    );
  }
}

class _ReaderCanvas extends StatelessWidget {
  const _ReaderCanvas({
    required this.surah,
    required this.controller,
    required this.palette,
    required this.fontSize,
    required this.isFullscreen,
    required this.scrollController,
    required this.ayahAnchorKeyFor,
  });

  final SurahData surah;
  final QuranAppController controller;
  final _ReaderPalette palette;
  final double fontSize;
  final bool isFullscreen;
  final ScrollController scrollController;
  final GlobalKey Function(int ayahNumber) ayahAnchorKeyFor;

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      key: const Key('reader-scroll-view'),
      controller: scrollController,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isFullscreen ? 20 : 20,
            isFullscreen ? 76 : 24,
            isFullscreen ? 20 : 20,
            isFullscreen ? 28 : 28,
          ),
          child: _ContinuousAyahText(
            surah: surah,
            controller: controller,
            palette: palette,
            fontSize: fontSize,
            ayahAnchorKeyFor: ayahAnchorKeyFor,
          ),
        ),
      ),
    );

    if (isFullscreen) {
      return content;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.borderColor),
      ),
      child: content,
    );
  }
}

class _ContinuousAyahText extends StatefulWidget {
  const _ContinuousAyahText({
    required this.surah,
    required this.controller,
    required this.palette,
    required this.fontSize,
    required this.ayahAnchorKeyFor,
  });

  final SurahData surah;
  final QuranAppController controller;
  final _ReaderPalette palette;
  final double fontSize;
  final GlobalKey Function(int ayahNumber) ayahAnchorKeyFor;

  @override
  State<_ContinuousAyahText> createState() => _ContinuousAyahTextState();
}

class _ContinuousAyahTextState extends State<_ContinuousAyahText> {
  final GlobalKey _richTextKey = GlobalKey();

  SurahData get surah => widget.surah;
  QuranAppController get controller => widget.controller;
  _ReaderPalette get palette => widget.palette;
  double get fontSize => widget.fontSize;
  GlobalKey Function(int ayahNumber) get ayahAnchorKeyFor =>
      widget.ayahAnchorKeyFor;

  bool get _tajweedEnabled => controller.readerSettings.tajweedEnabled;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontFamily: 'UthmanicHafs',
          fontSize: fontSize,
          height: 1.85,
          color: palette.textColor,
        );
    final presentation = _buildPresentation(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final target =
            _wordTargetForOffset(details.localPosition, presentation);
        if (target == null) {
          return;
        }
        HapticFeedback.selectionClick();
        showAyahRangeDialog(
          context: context,
          controller: controller,
          surah: surah,
          tappedAyah: target.ayahNumber,
        );
      },
      onLongPressStart: (details) {
        final target =
            _wordTargetForOffset(details.localPosition, presentation);
        if (target == null) {
          return;
        }
        HapticFeedback.mediumImpact();
        showWordInsightDialog(
          context: context,
          controller: controller,
          request: target.request,
        );
      },
      child: KeyedSubtree(
        key: const Key('continuous-ayah-text'),
        child: RichText(
          key: _richTextKey,
          text: TextSpan(
            style: baseStyle,
            children: presentation.spans,
          ),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  _AyahTextPresentation _buildPresentation(BuildContext context) {
    final spans = <InlineSpan>[];
    final wordTargets = <_InteractiveWordTarget>[];
    var offset = 0;

    for (final ayah in surah.ayahs) {
      final tajweedData = _tajweedEnabled
          ? controller.tajweedFor(surah.index, ayah.number)
          : null;
      final ayahText = tajweedData?.plainText ?? ayah.renderedText;
      final displayRuns = normalizeTajweedRunsForDisplay(
        tajweedData?.runs ?? [TajweedRun(text: ayahText)],
      );
      final savedColor = controller.isAyahSaved(surah, ayah.number)
          ? palette.savedAyahColor
          : Colors.transparent;
      final tokenMatches = RegExp(r'\s+|\S+').allMatches(ayahText);
      var occurrenceIndex = 0;

      for (final match in tokenMatches) {
        final token = match.group(0) ?? '';
        if (token.trim().isEmpty) {
          continue;
        }

        occurrenceIndex += 1;
        wordTargets.add(
          _InteractiveWordTarget(
            range: TextRange(
              start: offset + match.start,
              end: offset + match.end,
            ),
            ayahNumber: ayah.number,
            request: WordInsightRequest(
              surahIndex: surah.index,
              surahName: surah.englishName,
              ayahNumber: ayah.number,
              ayahText: ayahText,
              word: token,
              occurrenceIndex: occurrenceIndex,
            ),
          ),
        );
      }

      spans.add(_buildAyahTextSpan(displayRuns, savedColor));
      offset += ayahText.length;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            key: ayahAnchorKeyFor(ayah.number),
            child: GestureDetector(
              key: Key('ayah-${surah.index}-${ayah.number}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                showAyahRangeDialog(
                  context: context,
                  controller: controller,
                  surah: surah,
                  tappedAyah: ayah.number,
                );
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                showAyahInsightDialog(
                  context: context,
                  controller: controller,
                  request: AyahInsightRequest(
                    surahIndex: surah.index,
                    surahName: surah.englishName,
                    ayahNumber: ayah.number,
                    ayahText: ayahText,
                  ),
                );
              },
              child: _AyahMarker(
                number: ayah.number,
                fillColor: palette.markerFillColor,
              ),
            ),
          ),
        ),
      );
      offset += 1;
      spans.add(const TextSpan(text: '  '));
      offset += 2;
    }

    return _AyahTextPresentation(
      spans: spans,
      wordTargets: wordTargets,
    );
  }

  InlineSpan _buildAyahTextSpan(List<TajweedRun> runs, Color savedColor) {
    return TextSpan(
      style: TextStyle(backgroundColor: savedColor),
      children: [
        for (final run in runs)
          for (final splitRun in splitQuranTextRuns(run.text))
            TextSpan(
              text: splitRun.text,
              style: TextStyle(
                fontFamily: splitRun.isAnnotation ? 'MeQuran' : null,
                color: _colorForTajweedBucket(run.bucket),
                backgroundColor: savedColor,
              ),
            ),
      ],
    );
  }

  Color? _colorForTajweedBucket(TajweedLegendBucket? bucket) {
    if (bucket == null) {
      return null;
    }
    return _tajweedLegendColors[bucket];
  }

  _InteractiveWordTarget? _wordTargetForOffset(
    Offset localPosition,
    _AyahTextPresentation presentation,
  ) {
    final renderObject = _richTextKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) {
      return null;
    }
    final position = renderObject.getPositionForOffset(localPosition);
    for (final target in presentation.wordTargets) {
      if (position.offset >= target.range.start &&
          position.offset < target.range.end) {
        return target;
      }
    }
    return null;
  }
}

class _AyahTextPresentation {
  const _AyahTextPresentation({
    required this.spans,
    required this.wordTargets,
  });

  final List<InlineSpan> spans;
  final List<_InteractiveWordTarget> wordTargets;
}

class _InteractiveWordTarget {
  const _InteractiveWordTarget({
    required this.range,
    required this.ayahNumber,
    required this.request,
  });

  final TextRange range;
  final int ayahNumber;
  final WordInsightRequest request;
}

class _AyahMarker extends StatelessWidget {
  const _AyahMarker({
    required this.number,
    required this.fillColor,
  });

  final int number;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

const Map<TajweedLegendBucket, Color> _tajweedLegendColors = {
  TajweedLegendBucket.ikhfa: Color(0xFFA25203),
  TajweedLegendBucket.idghamWithGhunnah: Color(0xFFB70101),
  TajweedLegendBucket.iqlab: Color(0xFF9C36AC),
  TajweedLegendBucket.idghamWithoutGhunnah: Color(0xFF707070),
  TajweedLegendBucket.izhar: Color(0xFF3365C8),
  TajweedLegendBucket.qalqalah: Color(0xFF237501),
};

class _FullscreenToolbar extends StatelessWidget {
  const _FullscreenToolbar({
    required this.surah,
    required this.palette,
    required this.onBack,
    required this.onSettings,
    required this.onExitFullscreen,
  });

  final SurahData surah;
  final _ReaderPalette palette;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onExitFullscreen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.controlsBackgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: palette.toolbarColor,
              tooltip: 'Back',
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    surah.englishName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: palette.toolbarColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    surah.arabicName,
                    textDirection: TextDirection.rtl,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.toolbarColor,
                          fontFamily: 'UthmanicHafs',
                          fontSize: 20,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('reader-settings-button-fullscreen'),
              onPressed: onSettings,
              icon: const Icon(Icons.tune_rounded),
              color: palette.toolbarColor,
              tooltip: 'Reader settings',
            ),
            IconButton(
              key: const Key('reader-exit-fullscreen-button'),
              onPressed: onExitFullscreen,
              icon: const Icon(Icons.fullscreen_exit_rounded),
              color: palette.toolbarColor,
              tooltip: 'Exit full screen',
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    super.key,
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final _ReaderPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        width: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : palette.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: palette.scaffoldColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: palette.markerFillColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              palette.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPalette {
  const _ReaderPalette({
    required this.keyName,
    required this.label,
    required this.scaffoldColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.toolbarColor,
    required this.controlsBackgroundColor,
    required this.savedAyahColor,
    required this.markerFillColor,
    required this.isDark,
  });

  final String keyName;
  final String label;
  final Color scaffoldColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color toolbarColor;
  final Color controlsBackgroundColor;
  final Color savedAyahColor;
  final Color markerFillColor;
  final bool isDark;
}

const List<_ReaderPalette> _readerPalettes = [
  _ReaderPalette(
    keyName: 'paper',
    label: 'Paper',
    scaffoldColor: Color(0xFFF7F3E9),
    surfaceColor: Color(0xFFFFFCF5),
    borderColor: Color(0xFFE0D5C2),
    textColor: Color(0xFF11251F),
    secondaryTextColor: Color(0xFF415550),
    toolbarColor: Color(0xFF17362F),
    controlsBackgroundColor: Color(0xE6FFFCF5),
    savedAyahColor: Color(0x3329A587),
    markerFillColor: Color(0xFF0F766E),
    isDark: false,
  ),
  _ReaderPalette(
    keyName: 'mist',
    label: 'Mist',
    scaffoldColor: Color(0xFFEEF4F3),
    surfaceColor: Color(0xFFF9FEFD),
    borderColor: Color(0xFFD0DFDB),
    textColor: Color(0xFF102620),
    secondaryTextColor: Color(0xFF45615B),
    toolbarColor: Color(0xFF17362F),
    controlsBackgroundColor: Color(0xE6F9FEFD),
    savedAyahColor: Color(0x3329A587),
    markerFillColor: Color(0xFF0F766E),
    isDark: false,
  ),
  _ReaderPalette(
    keyName: 'sage',
    label: 'Sage',
    scaffoldColor: Color(0xFFE9F0E2),
    surfaceColor: Color(0xFFF8FCF3),
    borderColor: Color(0xFFD1DEC5),
    textColor: Color(0xFF18261C),
    secondaryTextColor: Color(0xFF4D6152),
    toolbarColor: Color(0xFF1C3525),
    controlsBackgroundColor: Color(0xE6F8FCF3),
    savedAyahColor: Color(0x3329A587),
    markerFillColor: Color(0xFF2D7A64),
    isDark: false,
  ),
  _ReaderPalette(
    keyName: 'midnight',
    label: 'Midnight',
    scaffoldColor: Color(0xFF0E1820),
    surfaceColor: Color(0xFF15222B),
    borderColor: Color(0xFF29414C),
    textColor: Color(0xFFF3F0E7),
    secondaryTextColor: Color(0xFFB0C2BE),
    toolbarColor: Color(0xFFF3F0E7),
    controlsBackgroundColor: Color(0xDD15222B),
    savedAyahColor: Color(0x3347D0B1),
    markerFillColor: Color(0xFF1BA08C),
    isDark: true,
  ),
];

_ReaderPalette _paletteFor(String key) {
  return _readerPalettes.firstWhere(
    (palette) => palette.keyName == key,
    orElse: () => _readerPalettes.first,
  );
}

Future<void> showAyahRangeDialog({
  required BuildContext context,
  required QuranAppController controller,
  required SurahData surah,
  required int tappedAyah,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _AyahRangeDialog(
        controller: controller,
        surah: surah,
        tappedAyah: tappedAyah,
      );
    },
  );
}

class _AyahRangeDialog extends StatefulWidget {
  const _AyahRangeDialog({
    required this.controller,
    required this.surah,
    required this.tappedAyah,
  });

  final QuranAppController controller;
  final SurahData surah;
  final int tappedAyah;

  @override
  State<_AyahRangeDialog> createState() => _AyahRangeDialogState();
}

class _AyahRangeDialogState extends State<_AyahRangeDialog> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  String _errorText = '';

  QuranAppController get controller => widget.controller;
  SurahData get surah => widget.surah;

  @override
  void initState() {
    super.initState();
    final suggestedRange = suggestedRangeForTappedAyah(
      savedRanges: controller.rangesFor(surah.index),
      tappedAyah: widget.tappedAyah,
    );
    _fromController = TextEditingController(
      text: '${suggestedRange.fromAyah}',
    );
    _toController = TextEditingController(
      text: '${suggestedRange.toAyah}',
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _saveRange() async {
    FocusScope.of(context).unfocus();
    final fromAyah = int.tryParse(_fromController.text.trim());
    final toAyah = int.tryParse(_toController.text.trim());
    if (fromAyah == null || toAyah == null) {
      setState(() => _errorText = 'Please enter numbers only.');
      return;
    }

    final result = await controller.saveRange(
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
    );
    if (!mounted) {
      return;
    }
    setState(() => _errorText = result ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ranges = controller.rangesFor(surah.index);
        final percent = controller.percentForSurah(surah);

        return AlertDialog(
          title: Text('${surah.englishName} progress'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save an ayah range just like QuranTracker, starting from the ayah you tapped or any range you type in.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('from-ayah-field'),
                          controller: _fromController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'From ayah',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('to-ayah-field'),
                          controller: _toController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'To ayah',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_errorText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('save-range-button'),
                    onPressed: _saveRange,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save range'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saved ranges',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (ranges.isEmpty)
                    const Text('No saved ranges yet.')
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: ranges.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final range = ranges[index];
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              title: Text(
                                'Ayah ${range.fromAyah} to ${range.toAyah}',
                              ),
                              trailing: IconButton(
                                key: Key('delete-range-$index'),
                                onPressed: () async {
                                  await controller.removeRangeAt(
                                    surah.index,
                                    index,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {});
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Read: ${formatPercent(percent)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
