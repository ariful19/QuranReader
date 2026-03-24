import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/ai_models.dart';
import 'package:quran_reader/src/ai_services.dart';
import 'package:quran_reader/src/app_controller.dart';
import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/progress_repository.dart';
import 'package:quran_reader/src/quran_repository.dart';

void main() {
  test('word insight uses cache and refresh bypasses cache', () async {
    final secretsStore = MemoryAiSecretsStore();
    await secretsStore.saveApiKey('test-api-key');
    final fakeGeminiClient = _CountingGeminiClient();
    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiSecretsStore: secretsStore,
      aiCacheRepository: MemoryAiCacheRepository(),
      geminiClient: fakeGeminiClient,
    );
    await controller.load();

    const request = WordInsightRequest(
      surahIndex: 1,
      surahName: 'The Opening',
      ayahNumber: 1,
      ayahText: 'كِتَابٌ مُبِينٌ',
      word: 'مُبِينٌ',
      occurrenceIndex: 2,
    );

    final first = await controller.getWordInsight(request: request);
    final second = await controller.getWordInsight(request: request);
    final refreshed = await controller.getWordInsight(
      request: request,
      refresh: true,
    );

    expect(first.isFromCache, isFalse);
    expect(second.isFromCache, isTrue);
    expect(refreshed.isFromCache, isFalse);
    expect(fakeGeminiClient.wordCalls, 2);
  });

  test('word insight throws when API key is missing', () async {
    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiSecretsStore: MemoryAiSecretsStore(),
      aiCacheRepository: MemoryAiCacheRepository(),
      geminiClient: _CountingGeminiClient(),
    );
    await controller.load();

    expect(
      () => controller.getWordInsight(
        request: const WordInsightRequest(
          surahIndex: 1,
          surahName: 'The Opening',
          ayahNumber: 1,
          ayahText: 'كِتَابٌ مُبِينٌ',
          word: 'مُبِينٌ',
          occurrenceIndex: 2,
        ),
      ),
      throwsA(isA<MissingGeminiApiKeyException>()),
    );
  });
}

class _CountingGeminiClient extends GeminiClient {
  int wordCalls = 0;

  @override
  void close() {}

  @override
  Future<WordInsightRecord> generateWordInsight({
    required String apiKey,
    required WordInsightRequest request,
  }) async {
    wordCalls += 1;
    return WordInsightRecord(
      surahIndex: request.surahIndex,
      ayahNumber: request.ayahNumber,
      word: request.word,
      normalizedWord: request.normalizedWord,
      occurrenceIndex: request.occurrenceIndex,
      promptVersion: GeminiClient.wordInsightPromptVersion,
      model: GeminiClient.wordModelName,
      generatedAt: DateTime(2026, 3, 24),
      insight: const WordInsight(
        word: 'مُبِينٌ',
        bengaliMeaning: 'স্পষ্ট',
        contextualMeaning: 'প্রসঙ্গে স্পষ্ট',
        root: 'ب ي ن',
        masdar: 'بَيَان',
        partOfSpeech: 'বিশেষণ',
        linguisticNotes: 'নোট',
        confidenceNote: 'নিশ্চয়তার নোট',
      ),
    );
  }
}

class _SimpleCatalogSource implements CatalogSource {
  @override
  Future<List<SurahData>> loadCatalog() async {
    return const [
      SurahData(
        index: 1,
        arabicName: 'الفاتحة',
        englishName: 'The Opening',
        chronologicalOrder: 5,
        totalUnicodeChars: 42,
        ayahs: [
          AyahData(
            number: 1,
            text: 'كِتَابٌ مُبِينٌ',
          ),
        ],
      ),
    ];
  }
}

class _MemoryStateStore implements AppStateStore {
  PersistedState? _state;

  @override
  Future<void> clear() async {
    _state = null;
  }

  @override
  Future<PersistedState?> load() async => _state;

  @override
  Future<void> save(PersistedState state) async {
    _state = state;
  }
}
