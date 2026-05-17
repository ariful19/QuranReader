import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'ai_models.dart';
import 'ai_services.dart';
import 'models.dart';
import 'progress_repository.dart';
import 'progress_sync_service.dart';
import 'quran_repository.dart';

class QuranAppController extends ChangeNotifier {
  QuranAppController({
    required CatalogSource catalogSource,
    required AppStateStore appStateStore,
    TajweedSource? tajweedSource,
    AiSecretsStore? aiSecretsStore,
    AiCacheRepository? aiCacheRepository,
    GeminiClient? geminiClient,
    ProgressSyncService? progressSyncService,
  })  : _catalogSource = catalogSource,
        _appStateStore = appStateStore,
        _tajweedSource = tajweedSource ?? const EmptyTajweedSource(),
        _aiSecretsStore = aiSecretsStore ?? MemoryAiSecretsStore(),
        _aiCacheRepository = aiCacheRepository ?? MemoryAiCacheRepository(),
        _geminiClient = geminiClient ?? GeminiClient(),
        _progressSyncService = progressSyncService ??
            const DisabledProgressSyncService(
              'Sync is unavailable in this build.',
            );

  final CatalogSource _catalogSource;
  final AppStateStore _appStateStore;
  final TajweedSource _tajweedSource;
  final AiSecretsStore _aiSecretsStore;
  final AiCacheRepository _aiCacheRepository;
  final GeminiClient _geminiClient;
  final ProgressSyncService _progressSyncService;

  bool _isReady = false;
  List<SurahData> _catalog = const [];
  Map<int, Map<int, TajweedAyahData>> _tajweedBySurah = const {};
  Map<int, SurahProgress> _progressBySurah = const {};
  SurahOrderMode _orderMode = SurahOrderMode.normal;
  GoalState? _goalState;
  int _goalUpdatedAtEpochMs = 0;
  ReaderSettings _readerSettings = ReaderSettings.defaults;
  LastSavedRangeBookmark? _lastSavedRangeBookmark;
  Map<int, int> _lastReadAyahBySurah = const {};
  Map<int, int> _lastReadUpdatedAtBySurah = const {};
  bool _hasGeminiApiKey = false;
  String _syncKey = '';
  int? _lastSyncAtEpochMs;
  bool _isSyncing = false;
  int _catalogTotalUnicodeChars = 0;
  Map<int, int> _readUnicodeCharsBySurah = const {};
  int _totalReadUnicodeChars = 0;
  List<SurahData> _visibleSurahsCache = const [];
  bool _isVisibleSurahsDirty = true;

  static const _uuid = Uuid();

  static Future<QuranAppController> create() async {
    final controller = QuranAppController(
      catalogSource: const AssetQuranCatalogSource(),
      appStateStore: await SharedPreferencesAppStateStore.create(),
      tajweedSource: const AssetTajweedSource(),
      aiSecretsStore: FlutterSecureAiSecretsStore(),
      aiCacheRepository: await SqfliteAiCacheRepository.open(),
      geminiClient: GeminiClient(),
      progressSyncService: await createProgressSyncService(),
    );
    await controller.load();
    return controller;
  }

  bool get isReady => _isReady;

  SurahOrderMode get orderMode => _orderMode;

  GoalState? get goalState => _goalState;

  ReaderSettings get readerSettings => _readerSettings;

  LastSavedRangeBookmark? get lastSavedRangeBookmark => _lastSavedRangeBookmark;

  int? lastReadAyahFor(int surahIndex) => _lastReadAyahBySurah[surahIndex];

  String get syncKey => _syncKey;

  bool get isSyncAvailable => _progressSyncService.isAvailable;

  String? get syncUnavailableReason => _progressSyncService.unavailableReason;

  bool get isSyncing => _isSyncing;

  DateTime? get lastSyncAt => _lastSyncAtEpochMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_lastSyncAtEpochMs!);

  TajweedAyahData? tajweedFor(int surahIndex, int ayahNumber) {
    return _tajweedBySurah[surahIndex]?[ayahNumber];
  }

  bool get hasGeminiApiKey => _hasGeminiApiKey;

  List<SurahData> get visibleSurahs {
    if (!_isVisibleSurahsDirty) {
      return _visibleSurahsCache;
    }

    final surahs = [..._catalog];
    surahs.sort((left, right) {
      return switch (_orderMode) {
        SurahOrderMode.normal => left.index.compareTo(right.index),
        SurahOrderMode.chronological =>
          left.chronologicalOrder.compareTo(right.chronologicalOrder),
        SurahOrderMode.readPercentage => _compareByReadPercentage(left, right),
      };
    });
    _visibleSurahsCache = List<SurahData>.unmodifiable(surahs);
    _isVisibleSurahsDirty = false;
    return _visibleSurahsCache;
  }

  int _compareByReadPercentage(SurahData left, SurahData right) {
    int group(SurahData s) {
      final readUnicodeChars = readUnicodeCharsFor(s);
      if (readUnicodeChars > 0 && readUnicodeChars < s.totalUnicodeChars) {
        return 0;
      }
      if (readUnicodeChars == 0) {
        return 1;
      }
      return 2;
    }

    final gLeft = group(left);
    final gRight = group(right);
    if (gLeft != gRight) return gLeft.compareTo(gRight);

    return left.index.compareTo(right.index);
  }

  double get totalPercent {
    if (_catalogTotalUnicodeChars == 0) {
      return 0;
    }
    return (_totalReadUnicodeChars / _catalogTotalUnicodeChars) * 100;
  }

  int get totalReadUnicodeChars => _totalReadUnicodeChars;

  GoalMetrics? get goalMetrics {
    final currentGoal = _goalState;
    if (currentGoal == null || _catalog.isEmpty) {
      return null;
    }

    final today = dateOnly(DateTime.now());
    final goalDate = dateOnly(currentGoal.goalDate);
    final totalUnicodeChars = _catalogTotalUnicodeChars;
    final readUnicodeChars = _totalReadUnicodeChars;
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
    _catalogTotalUnicodeChars = _catalog.fold<int>(
      0,
      (sum, surah) => sum + surah.totalUnicodeChars,
    );
    _tajweedBySurah = await _tajweedSource.loadTajweed();
    _progressBySurah = _emptyProgressBySurah();

    final persistedState = await _appStateStore.load();
    var shouldPersist = false;
    if (persistedState != null) {
      _orderMode = persistedState.orderMode;
      _goalState = persistedState.goalState;
      _goalUpdatedAtEpochMs = persistedState.goalUpdatedAtEpochMs;
      _readerSettings = persistedState.readerSettings;
      _syncKey = persistedState.syncKey;
      _lastSyncAtEpochMs = persistedState.lastSyncAtEpochMs;
      _lastSavedRangeBookmark = persistedState.lastSavedRangeBookmark;
      _lastReadAyahBySurah = persistedState.lastReadAyahBySurah;
      _lastReadUpdatedAtBySurah = persistedState.lastReadUpdatedAtBySurah;
      _progressBySurah = {
        for (final surah in _catalog)
          surah.index: persistedState.progressBySurah[surah.index] ??
              SurahProgress.empty,
      };
    }
    if (_syncKey.isEmpty) {
      _syncKey = _uuid.v4();
      shouldPersist = true;
    }
    _refreshDerivedProgressState();
    _hasGeminiApiKey = await _aiSecretsStore.loadApiKey() != null;
    if (shouldPersist) {
      await _persist();
    }

    _isReady = true;
    notifyListeners();
  }

  SurahData surahByIndex(int surahIndex) {
    return _catalog.firstWhere((surah) => surah.index == surahIndex);
  }

  SurahData? trySurahByIndex(int surahIndex) {
    for (final surah in _catalog) {
      if (surah.index == surahIndex) {
        return surah;
      }
    }
    return null;
  }

  SurahProgress progressFor(int surahIndex) {
    return _progressBySurah[surahIndex] ?? SurahProgress.empty;
  }

  List<AyahRange> rangesFor(int surahIndex) {
    return progressFor(surahIndex).ranges;
  }

  int? furthestSavedAyahFor(int surahIndex) {
    final ranges = rangesFor(surahIndex);
    if (ranges.isEmpty) {
      return null;
    }

    return ranges.fold<int>(
      ranges.first.toAyah,
      (furthestAyah, range) => math.max(furthestAyah, range.toAyah),
    );
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
    return _readUnicodeCharsBySurah[surah.index] ?? 0;
  }

  int _readUnicodeCharsForRanges(SurahData surah, Iterable<AyahRange> ranges) {
    var total = 0;
    for (final range in ranges) {
      for (var ayahIndex = range.fromAyah;
          ayahIndex <= range.toAyah;
          ayahIndex += 1) {
        total += surah.ayahs[ayahIndex - 1].unicodeChars;
      }
    }
    return total;
  }

  void _refreshDerivedProgressState() {
    final readUnicodeCharsBySurah = <int, int>{};
    var totalReadUnicodeChars = 0;

    for (final surah in _catalog) {
      final readUnicodeChars = _readUnicodeCharsForRanges(
        surah,
        _progressBySurah[surah.index]?.ranges ?? const [],
      );
      readUnicodeCharsBySurah[surah.index] = readUnicodeChars;
      totalReadUnicodeChars += readUnicodeChars;
    }

    _readUnicodeCharsBySurah = readUnicodeCharsBySurah;
    _totalReadUnicodeChars = totalReadUnicodeChars;
    _isVisibleSurahsDirty = true;
  }

  Future<void> setOrderMode(SurahOrderMode mode) async {
    if (_orderMode == mode) {
      return;
    }
    _orderMode = mode;
    _isVisibleSurahsDirty = true;
    await _persistAndNotify();
  }

  Future<void> toggleSurahComplete(SurahData surah, bool isComplete) async {
    final updatedAt = _timestampNow();
    _progressBySurah = {
      ..._progressBySurah,
      surah.index: isComplete
          ? SurahProgress(
              ranges: [
                AyahRange(fromAyah: 1, toAyah: surah.ayahCount),
              ],
              updatedAtEpochMs: updatedAt,
            )
          : SurahProgress(updatedAtEpochMs: updatedAt),
    };
    _refreshDerivedProgressState();
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

    final updatedAt = _timestampNow();
    _progressBySurah = {
      ..._progressBySurah,
      surah.index: SurahProgress(
        ranges: mergedRanges,
        updatedAtEpochMs: updatedAt,
      ),
    };
    _lastSavedRangeBookmark = LastSavedRangeBookmark(
      surahIndex: surah.index,
      fromAyah: fromAyah,
      toAyah: toAyah,
    );
    _refreshDerivedProgressState();
    await _persistAndNotify();
    return null;
  }

  Future<void> removeRangeAt(int surahIndex, int rangeIndex) async {
    final currentRanges = [...rangesFor(surahIndex)];
    if (rangeIndex < 0 || rangeIndex >= currentRanges.length) {
      return;
    }
    final removedRange = currentRanges.removeAt(rangeIndex);
    final currentBookmark = _lastSavedRangeBookmark;
    if (currentBookmark != null &&
        currentBookmark.surahIndex == surahIndex &&
        removedRange.contains(currentBookmark.fromAyah) &&
        removedRange.contains(currentBookmark.toAyah)) {
      _lastSavedRangeBookmark = null;
    }
    final updatedAt = _timestampNow();
    _progressBySurah = {
      ..._progressBySurah,
      surahIndex: SurahProgress(
        ranges: currentRanges,
        updatedAtEpochMs: updatedAt,
      ),
    };
    _refreshDerivedProgressState();
    await _persistAndNotify();
  }

  Future<String?> saveGoal(DateTime goalDate) async {
    final normalizedGoalDate = dateOnly(goalDate);
    final today = dateOnly(DateTime.now());
    if (normalizedGoalDate.isBefore(today)) {
      return 'Goal date must be today or later.';
    }

    _goalUpdatedAtEpochMs = _timestampNow();
    _goalState = GoalState(
      goalDate: normalizedGoalDate,
      startDate: _goalState?.startDate ?? today,
    );
    await _persistAndNotify();
    return null;
  }

  Future<void> clearGoal() async {
    _goalState = null;
    _goalUpdatedAtEpochMs = _timestampNow();
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

  Future<void> setReaderTajweedEnabled(bool enabled) async {
    if (_readerSettings.tajweedEnabled == enabled) {
      return;
    }
    _readerSettings = _readerSettings.copyWith(tajweedEnabled: enabled);
    await _persistAndNotify();
  }

  Future<void> saveLastReadAyah({
    required int surahIndex,
    required int ayahNumber,
  }) async {
    final surah = trySurahByIndex(surahIndex);
    if (surah == null || ayahNumber < 1 || ayahNumber > surah.ayahCount) {
      return;
    }
    if (_lastReadAyahBySurah[surahIndex] == ayahNumber) {
      return;
    }

    _lastReadAyahBySurah = {
      ..._lastReadAyahBySurah,
      surahIndex: ayahNumber,
    };
    _lastReadUpdatedAtBySurah = {
      ..._lastReadUpdatedAtBySurah,
      surahIndex: _timestampNow(),
    };
    await _persist();
  }

  Future<void> resetAllProgress() async {
    final updatedAt = _timestampNow();
    _orderMode = SurahOrderMode.normal;
    _goalState = null;
    _goalUpdatedAtEpochMs = updatedAt;
    _lastSavedRangeBookmark = null;
    _lastReadAyahBySurah = const {};
    _lastReadUpdatedAtBySurah = {
      for (final surah in _catalog) surah.index: updatedAt,
    };
    _progressBySurah = _emptyProgressBySurah(updatedAtEpochMs: updatedAt);
    _refreshDerivedProgressState();
    await _persistAndNotify();
  }

  Future<String?> syncProgress(String syncKey) async {
    final normalizedKey = _normalizeSyncKey(syncKey);
    if (normalizedKey == null) {
      return 'Enter a valid sync key.';
    }
    if (!_progressSyncService.isAvailable) {
      return _progressSyncService.unavailableReason ?? 'Sync is unavailable.';
    }

    if (_syncKey != normalizedKey) {
      _syncKey = normalizedKey;
      await _persist();
    }

    _isSyncing = true;
    notifyListeners();
    try {
      final remoteSnapshot = await _progressSyncService.fetch(normalizedKey);
      if (remoteSnapshot != null) {
        _mergeRemoteSnapshot(remoteSnapshot);
      }
      await _progressSyncService.save(_createSyncSnapshot(normalizedKey));
      _lastSyncAtEpochMs = _timestampNow();
      await _persist();
      return null;
    } on ProgressSyncUnavailableException catch (error) {
      return error.message;
    } catch (error) {
      return 'Sync failed: $error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
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

  Future<void> _persist() {
    return _appStateStore.save(
      PersistedState(
        orderMode: _orderMode,
        progressBySurah: _progressBySurah,
        goalState: _goalState,
        goalUpdatedAtEpochMs: _goalUpdatedAtEpochMs,
        readerSettings: _readerSettings,
        syncKey: _syncKey,
        lastSyncAtEpochMs: _lastSyncAtEpochMs,
        lastSavedRangeBookmark: _lastSavedRangeBookmark,
        lastReadAyahBySurah: _lastReadAyahBySurah,
        lastReadUpdatedAtBySurah: _lastReadUpdatedAtBySurah,
      ),
    );
  }

  Future<void> _persistAndNotify() async {
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _geminiClient.close();
    _aiCacheRepository.close();
    super.dispose();
  }

  Map<int, SurahProgress> _emptyProgressBySurah({int updatedAtEpochMs = 0}) {
    return {
      for (final surah in _catalog)
        surah.index: SurahProgress(updatedAtEpochMs: updatedAtEpochMs),
    };
  }

  SyncProgressSnapshot _createSyncSnapshot(String syncKey) {
    return SyncProgressSnapshot(
      syncKey: syncKey,
      progressBySurah: {
        for (final entry in _progressBySurah.entries)
          entry.key: entry.value.copyWith(
            ranges: List<AyahRange>.unmodifiable(entry.value.ranges),
          ),
      },
      goalState: _goalState,
      goalUpdatedAtEpochMs: _goalUpdatedAtEpochMs,
      lastReadAyahBySurah: Map<int, int>.unmodifiable(_lastReadAyahBySurah),
      lastReadUpdatedAtBySurah: Map<int, int>.unmodifiable(
        _lastReadUpdatedAtBySurah,
      ),
    );
  }

  void _mergeRemoteSnapshot(SyncProgressSnapshot remoteSnapshot) {
    _progressBySurah = {
      for (final surah in _catalog)
        surah.index: _mergeSurahProgress(
          _progressBySurah[surah.index] ?? SurahProgress.empty,
          remoteSnapshot.progressBySurah[surah.index] ?? SurahProgress.empty,
        ),
    };

    final localGoalUpdatedAt = _goalUpdatedAtEpochMs;
    final remoteGoalUpdatedAt = remoteSnapshot.goalUpdatedAtEpochMs;
    if (remoteGoalUpdatedAt > localGoalUpdatedAt ||
        (remoteGoalUpdatedAt == localGoalUpdatedAt &&
            _goalState == null &&
            remoteSnapshot.goalState != null)) {
      _goalState = remoteSnapshot.goalState;
      _goalUpdatedAtEpochMs = remoteGoalUpdatedAt;
    }

    final mergedLastReadAyahBySurah = <int, int>{};
    final mergedLastReadUpdatedAtBySurah = <int, int>{};
    for (final surah in _catalog) {
      final surahIndex = surah.index;
      final localUpdatedAt = _lastReadUpdatedAtBySurah[surahIndex] ?? 0;
      final remoteUpdatedAt =
          remoteSnapshot.lastReadUpdatedAtBySurah[surahIndex] ?? 0;
      final localAyah = _lastReadAyahBySurah[surahIndex];
      final remoteAyah = remoteSnapshot.lastReadAyahBySurah[surahIndex];

      if (remoteUpdatedAt > localUpdatedAt) {
        _writeMergedLastRead(
          mergedLastReadAyahBySurah,
          mergedLastReadUpdatedAtBySurah,
          surahIndex: surahIndex,
          ayahNumber: remoteAyah,
          updatedAtEpochMs: remoteUpdatedAt,
        );
        continue;
      }
      if (localUpdatedAt > remoteUpdatedAt) {
        _writeMergedLastRead(
          mergedLastReadAyahBySurah,
          mergedLastReadUpdatedAtBySurah,
          surahIndex: surahIndex,
          ayahNumber: localAyah,
          updatedAtEpochMs: localUpdatedAt,
        );
        continue;
      }

      final mergedAyah = remoteAyah ?? localAyah;
      _writeMergedLastRead(
        mergedLastReadAyahBySurah,
        mergedLastReadUpdatedAtBySurah,
        surahIndex: surahIndex,
        ayahNumber: mergedAyah,
        updatedAtEpochMs: localUpdatedAt,
      );
    }

    _lastReadAyahBySurah = mergedLastReadAyahBySurah;
    _lastReadUpdatedAtBySurah = mergedLastReadUpdatedAtBySurah;
    _refreshDerivedProgressState();
  }

  SurahProgress _mergeSurahProgress(
    SurahProgress localProgress,
    SurahProgress remoteProgress,
  ) {
    if (remoteProgress.updatedAtEpochMs > localProgress.updatedAtEpochMs) {
      return remoteProgress;
    }
    if (localProgress.updatedAtEpochMs > remoteProgress.updatedAtEpochMs) {
      return localProgress;
    }
    if (remoteProgress.ranges.isEmpty) {
      return localProgress;
    }
    if (localProgress.ranges.isEmpty) {
      return remoteProgress;
    }
    return SurahProgress(
      ranges: mergeAyahRanges([
        ...localProgress.ranges,
        ...remoteProgress.ranges,
      ]),
      updatedAtEpochMs: localProgress.updatedAtEpochMs,
    );
  }

  void _writeMergedLastRead(
    Map<int, int> mergedLastReadAyahBySurah,
    Map<int, int> mergedLastReadUpdatedAtBySurah, {
    required int surahIndex,
    required int? ayahNumber,
    required int updatedAtEpochMs,
  }) {
    if (updatedAtEpochMs > 0) {
      mergedLastReadUpdatedAtBySurah[surahIndex] = updatedAtEpochMs;
    }
    if (ayahNumber != null) {
      mergedLastReadAyahBySurah[surahIndex] = ayahNumber;
    }
  }

  String? _normalizeSyncKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.contains('/') ||
        RegExp(r'\s').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  int _timestampNow() => DateTime.now().millisecondsSinceEpoch;
}

class MissingGeminiApiKeyException implements Exception {
  const MissingGeminiApiKeyException();

  @override
  String toString() => 'Missing Gemini API key.';
}
