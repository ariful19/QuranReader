import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'ai_models.dart';
import 'ai_services.dart';
import 'models.dart';
import 'progress_repository.dart';
import 'quran_repository.dart';

class QuranAppController extends ChangeNotifier {
  QuranAppController({
    required CatalogSource catalogSource,
    required AppStateStore appStateStore,
    AiSecretsStore? aiSecretsStore,
    AiCacheRepository? aiCacheRepository,
    GeminiClient? geminiClient,
  })  : _catalogSource = catalogSource,
        _appStateStore = appStateStore,
        _aiSecretsStore = aiSecretsStore ?? MemoryAiSecretsStore(),
        _aiCacheRepository = aiCacheRepository ?? MemoryAiCacheRepository(),
        _geminiClient = geminiClient ?? GeminiClient();

  final CatalogSource _catalogSource;
  final AppStateStore _appStateStore;
  final AiSecretsStore _aiSecretsStore;
  final AiCacheRepository _aiCacheRepository;
  final GeminiClient _geminiClient;

  bool _isReady = false;
  List<SurahData> _catalog = const [];
  Map<int, SurahProgress> _progressBySurah = const {};
  SurahOrderMode _orderMode = SurahOrderMode.normal;
  GoalState? _goalState;
  ReaderSettings _readerSettings = ReaderSettings.defaults;
  bool _hasGeminiApiKey = false;

  static Future<QuranAppController> create() async {
    final controller = QuranAppController(
      catalogSource: const AssetQuranCatalogSource(),
      appStateStore: await SharedPreferencesAppStateStore.create(),
      aiSecretsStore: FlutterSecureAiSecretsStore(),
      aiCacheRepository: await SqfliteAiCacheRepository.open(),
      geminiClient: GeminiClient(),
    );
    await controller.load();
    return controller;
  }

  bool get isReady => _isReady;

  SurahOrderMode get orderMode => _orderMode;

  GoalState? get goalState => _goalState;

  ReaderSettings get readerSettings => _readerSettings;

  bool get hasGeminiApiKey => _hasGeminiApiKey;

  List<SurahData> get visibleSurahs {
    final surahs = [..._catalog];
    surahs.sort((left, right) {
      return switch (_orderMode) {
        SurahOrderMode.normal => left.index.compareTo(right.index),
        SurahOrderMode.chronological =>
          left.chronologicalOrder.compareTo(right.chronologicalOrder),
      };
    });
    return surahs;
  }

  double get totalPercent {
    final totalUnicodeChars = _catalog.fold<int>(
      0,
      (sum, surah) => sum + surah.totalUnicodeChars,
    );
    if (totalUnicodeChars == 0) {
      return 0;
    }
    return (totalReadUnicodeChars / totalUnicodeChars) * 100;
  }

  int get totalReadUnicodeChars {
    return _catalog.fold<int>(
      0,
      (sum, surah) => sum + readUnicodeCharsFor(surah),
    );
  }

  GoalMetrics? get goalMetrics {
    final currentGoal = _goalState;
    if (currentGoal == null || _catalog.isEmpty) {
      return null;
    }

    final today = dateOnly(DateTime.now());
    final goalDate = dateOnly(currentGoal.goalDate);
    final totalUnicodeChars = _catalog.fold<int>(
      0,
      (sum, surah) => sum + surah.totalUnicodeChars,
    );
    final readUnicodeChars = totalReadUnicodeChars;
    final remainingUnicodeChars =
        math.max(0, totalUnicodeChars - readUnicodeChars);
    final remainingPercent = totalUnicodeChars == 0
        ? 0.0
        : (remainingUnicodeChars / totalUnicodeChars) * 100;

    final elapsedDays = math.max(
      1,
      today.difference(dateOnly(currentGoal.startDate)).inDays,
    );
    final charsPerDay = elapsedDays == 0 ? 0 : readUnicodeChars ~/ elapsedDays;
    final estimatedDays =
        charsPerDay > 0 ? (remainingUnicodeChars / charsPerDay).ceil() : null;
    final projectedCompletionDate =
        estimatedDays == null ? null : today.add(Duration(days: estimatedDays));

    final daysRemaining = goalDate.difference(today).inDays;
    final requiredDailyPercent = daysRemaining > 0
        ? ((remainingUnicodeChars / daysRemaining).ceil() /
                totalUnicodeChars.toDouble()) *
            100
        : null;

    return GoalMetrics(
      daysRemaining: daysRemaining,
      remainingPercent: remainingPercent,
      estimatedDays: estimatedDays,
      projectedCompletionDate: projectedCompletionDate,
      requiredDailyPercent: requiredDailyPercent,
    );
  }

  Future<void> load() async {
    if (_isReady) {
      return;
    }

    _catalog = await _catalogSource.loadCatalog();
    _progressBySurah = {
      for (final surah in _catalog) surah.index: SurahProgress.empty,
    };

    final persistedState = await _appStateStore.load();
    if (persistedState != null) {
      _orderMode = persistedState.orderMode;
      _goalState = persistedState.goalState;
      _readerSettings = persistedState.readerSettings;
      _progressBySurah = {
        for (final surah in _catalog)
          surah.index: persistedState.progressBySurah[surah.index] ??
              SurahProgress.empty,
      };
    }
    _hasGeminiApiKey = await _aiSecretsStore.loadApiKey() != null;

    _isReady = true;
    notifyListeners();
  }

  SurahData surahByIndex(int surahIndex) {
    return _catalog.firstWhere((surah) => surah.index == surahIndex);
  }

  SurahProgress progressFor(int surahIndex) {
    return _progressBySurah[surahIndex] ?? SurahProgress.empty;
  }

  List<AyahRange> rangesFor(int surahIndex) {
    return progressFor(surahIndex).ranges;
  }

  double percentForSurah(SurahData surah) {
    if (surah.totalUnicodeChars == 0) {
      return 0;
    }
    return (readUnicodeCharsFor(surah) / surah.totalUnicodeChars) * 100;
  }

  bool isSurahComplete(SurahData surah) {
    return readUnicodeCharsFor(surah) >= surah.totalUnicodeChars;
  }

  bool isAyahSaved(SurahData surah, int ayahNumber) {
    return rangesFor(surah.index).any((range) => range.contains(ayahNumber));
  }

  int readUnicodeCharsFor(SurahData surah) {
    var total = 0;
    for (final range in rangesFor(surah.index)) {
      for (var ayahIndex = range.fromAyah;
          ayahIndex <= range.toAyah;
          ayahIndex += 1) {
        total += surah.ayahs[ayahIndex - 1].unicodeChars;
      }
    }
    return total;
  }

  Future<void> setOrderMode(SurahOrderMode mode) async {
    if (_orderMode == mode) {
      return;
    }
    _orderMode = mode;
    await _persistAndNotify();
  }

  Future<void> toggleSurahComplete(SurahData surah, bool isComplete) async {
    _progressBySurah = {
      ..._progressBySurah,
      surah.index: isComplete
          ? SurahProgress(
              ranges: [
                AyahRange(fromAyah: 1, toAyah: surah.ayahCount),
              ],
            )
          : SurahProgress.empty,
    };
    await _persistAndNotify();
  }

  Future<String?> saveRange({
    required SurahData surah,
    required int fromAyah,
    required int toAyah,
  }) async {
    if (fromAyah < 1 || toAyah < fromAyah || toAyah > surah.ayahCount) {
      return 'Please enter a valid ayah range.';
    }

    final mergedRanges = mergeAyahRanges(
      [
        ...rangesFor(surah.index),
        AyahRange(fromAyah: fromAyah, toAyah: toAyah),
      ],
    );

    _progressBySurah = {
      ..._progressBySurah,
      surah.index: SurahProgress(ranges: mergedRanges),
    };
    await _persistAndNotify();
    return null;
  }

  Future<void> removeRangeAt(int surahIndex, int rangeIndex) async {
    final currentRanges = [...rangesFor(surahIndex)];
    if (rangeIndex < 0 || rangeIndex >= currentRanges.length) {
      return;
    }
    currentRanges.removeAt(rangeIndex);
    _progressBySurah = {
      ..._progressBySurah,
      surahIndex: SurahProgress(ranges: currentRanges),
    };
    await _persistAndNotify();
  }

  Future<String?> saveGoal(DateTime goalDate) async {
    final normalizedGoalDate = dateOnly(goalDate);
    final today = dateOnly(DateTime.now());
    if (normalizedGoalDate.isBefore(today)) {
      return 'Goal date must be today or later.';
    }

    _goalState = GoalState(
      goalDate: normalizedGoalDate,
      startDate: _goalState?.startDate ?? today,
    );
    await _persistAndNotify();
    return null;
  }

  Future<void> clearGoal() async {
    _goalState = null;
    await _persistAndNotify();
  }

  Future<void> setReaderFontSize(double fontSize) async {
    final normalized = fontSize.clamp(
      ReaderSettings.minFontSize,
      ReaderSettings.maxFontSize,
    );
    if ((_readerSettings.fontSize - normalized).abs() < 0.01) {
      return;
    }
    _readerSettings = _readerSettings.copyWith(fontSize: normalized);
    await _persistAndNotify();
  }

  Future<void> setReaderBackgroundKey(String backgroundKey) async {
    if (_readerSettings.backgroundKey == backgroundKey) {
      return;
    }
    _readerSettings = _readerSettings.copyWith(backgroundKey: backgroundKey);
    await _persistAndNotify();
  }

  Future<void> resetAllProgress() async {
    _orderMode = SurahOrderMode.normal;
    _goalState = null;
    _progressBySurah = {
      for (final surah in _catalog) surah.index: SurahProgress.empty,
    };
    await _persistAndNotify();
  }

  Future<String?> saveGeminiApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      return 'Please enter a Gemini API key.';
    }
    await _aiSecretsStore.saveApiKey(normalized);
    _hasGeminiApiKey = true;
    notifyListeners();
    return null;
  }

  Future<void> deleteGeminiApiKey() async {
    await _aiSecretsStore.deleteApiKey();
    _hasGeminiApiKey = false;
    notifyListeners();
  }

  Future<void> clearAiCache() async {
    await _aiCacheRepository.clear();
    notifyListeners();
  }

  Future<InsightLoadResult<WordInsightRecord>> getWordInsight({
    required WordInsightRequest request,
    bool refresh = false,
  }) async {
    final apiKey = await _aiSecretsStore.loadApiKey();
    if (apiKey == null) {
      throw const MissingGeminiApiKeyException();
    }

    if (!refresh) {
      final cached = await _aiCacheRepository.getWordInsight(
        surahIndex: request.surahIndex,
        ayahNumber: request.ayahNumber,
        normalizedWord: request.normalizedWord,
        occurrenceIndex: request.occurrenceIndex,
        promptVersion: GeminiClient.wordInsightPromptVersion,
      );
      if (cached != null) {
        return InsightLoadResult(data: cached, isFromCache: true);
      }
    }

    final generated = await _geminiClient.generateWordInsight(
      apiKey: apiKey,
      request: request,
    );
    await _aiCacheRepository.saveWordInsight(generated);
    return InsightLoadResult(data: generated, isFromCache: false);
  }

  Future<InsightLoadResult<AyahInsightRecord>> getAyahInsight({
    required AyahInsightRequest request,
    bool refresh = false,
  }) async {
    final apiKey = await _aiSecretsStore.loadApiKey();
    if (apiKey == null) {
      throw const MissingGeminiApiKeyException();
    }

    if (!refresh) {
      final cached = await _aiCacheRepository.getAyahInsight(
        surahIndex: request.surahIndex,
        ayahNumber: request.ayahNumber,
        promptVersion: GeminiClient.ayahInsightPromptVersion,
      );
      if (cached != null) {
        return InsightLoadResult(data: cached, isFromCache: true);
      }
    }

    final generated = await _geminiClient.generateAyahInsight(
      apiKey: apiKey,
      request: request,
    );
    await _aiCacheRepository.saveAyahInsight(generated);
    return InsightLoadResult(data: generated, isFromCache: false);
  }

  Future<void> _persistAndNotify() async {
    await _appStateStore.save(
      PersistedState(
        orderMode: _orderMode,
        progressBySurah: _progressBySurah,
        goalState: _goalState,
        readerSettings: _readerSettings,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _geminiClient.close();
    _aiCacheRepository.close();
    super.dispose();
  }
}

class MissingGeminiApiKeyException implements Exception {
  const MissingGeminiApiKeyException();

  @override
  String toString() => 'Missing Gemini API key.';
}
