import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/ai_models.dart';
import 'package:quran_reader/src/ai_services.dart';
import 'package:quran_reader/src/app_controller.dart';
import 'package:quran_reader/src/home_page.dart';
import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/progress_repository.dart';
import 'package:quran_reader/src/quran_repository.dart';
import 'package:quran_reader/src/reader_page.dart';

void main() {
  testWidgets('settings page saves and removes Gemini API key', (tester) async {
    final secretsStore = MemoryAiSecretsStore();
    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiSecretsStore: secretsStore,
      aiCacheRepository: MemoryAiCacheRepository(),
      geminiClient: _FakeGeminiClient(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('gemini-api-key-field')),
      'test-api-key',
    );
    await tester.tap(find.byKey(const Key('save-gemini-api-key-button')));
    await tester.pumpAndSettle();

    expect(controller.hasGeminiApiKey, isTrue);
    expect(await secretsStore.loadApiKey(), 'test-api-key');
    expect(find.byKey(const Key('delete-gemini-api-key-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-gemini-api-key-button')));
    await tester.pumpAndSettle();

    expect(controller.hasGeminiApiKey, isFalse);
    expect(await secretsStore.loadApiKey(), isNull);
  });

  testWidgets('long pressing a word opens insight dialog and reuses cache',
      (tester) async {
    final secretsStore = MemoryAiSecretsStore();
    await secretsStore.saveApiKey('test-api-key');
    final fakeGeminiClient = _FakeGeminiClient();
    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiSecretsStore: secretsStore,
      aiCacheRepository: MemoryAiCacheRepository(),
      geminiClient: fakeGeminiClient,
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _longPressWord(tester, 'مُبِينٌ');
    expect(find.text('Word insight'), findsOneWidget);
    expect(find.text('স্পষ্ট'), findsOneWidget);
    expect(fakeGeminiClient.wordCalls, 1);

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    await _longPressWord(tester, 'مُبِينٌ');
    expect(find.text('Saved response'), findsOneWidget);
    expect(fakeGeminiClient.wordCalls, 1);
  });

  testWidgets('long pressing an ayah marker opens ayah insight dialog',
      (tester) async {
    final secretsStore = MemoryAiSecretsStore();
    await secretsStore.saveApiKey('test-api-key');
    final fakeGeminiClient = _FakeGeminiClient();
    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiSecretsStore: secretsStore,
      aiCacheRepository: MemoryAiCacheRepository(),
      geminiClient: fakeGeminiClient,
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('ayah-1-1')));
    await tester.pumpAndSettle();

    expect(find.text('Ayah insight'), findsOneWidget);
    expect(find.text('এটি একটি বাংলা ব্যাখ্যা।'), findsOneWidget);
    expect(fakeGeminiClient.ayahCalls, 1);
  });
}

Future<void> _longPressWord(WidgetTester tester, String word) async {
  final richTextFinder = find.descendant(
    of: find.byKey(const Key('continuous-ayah-text')),
    matching: find.byType(RichText),
  ).first;
  final richText = tester.widget<RichText>(richTextFinder);
  final renderParagraph = tester.renderObject<RenderParagraph>(richTextFinder);
  final plainText = richText.text.toPlainText(includePlaceholders: true);
  final start = plainText.indexOf(word);
  expect(start, greaterThanOrEqualTo(0));
  final boxes = renderParagraph.getBoxesForSelection(
    TextSelection(
      baseOffset: start,
      extentOffset: start + word.length,
    ),
  );
  expect(boxes, isNotEmpty);
  final globalCenter = renderParagraph.localToGlobal(boxes.first.toRect().center);
  await tester.longPressAt(globalCenter);
  await tester.pumpAndSettle();
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
          AyahData(
            number: 2,
            text: 'نُورٌ وَهُدًى',
          ),
        ],
      ),
    ];
  }
}

class _FakeGeminiClient extends GeminiClient {
  int wordCalls = 0;
  int ayahCalls = 0;

  @override
  void close() {}

  @override
  Future<AyahInsightRecord> generateAyahInsight({
    required String apiKey,
    required AyahInsightRequest request,
  }) async {
    ayahCalls += 1;
    return AyahInsightRecord(
      surahIndex: request.surahIndex,
      ayahNumber: request.ayahNumber,
      promptVersion: GeminiClient.ayahInsightPromptVersion,
      model: GeminiClient.ayahModelName,
      generatedAt: DateTime(2026, 3, 24, 10, 0),
      insight: const AyahInsight(
        bengaliMeaning: 'এটি একটি বাংলা অর্থ।',
        tafsirSummary: 'এটি একটি বাংলা ব্যাখ্যা।',
        keyThemes: 'হিদায়াত ও আলো।',
        practicalLessons: 'কুরআনের নির্দেশ মেনে চলা।',
        sources: [
          GroundingSource(
            title: 'Sample Source',
            url: 'https://example.com',
          ),
        ],
      ),
    );
  }

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
      generatedAt: DateTime(2026, 3, 24, 9, 30),
      insight: const WordInsight(
        word: 'مُبِينٌ',
        bengaliMeaning: 'স্পষ্ট',
        contextualMeaning: 'আয়াতে স্পষ্ট করে প্রকাশিত',
        root: 'ب ي ن',
        masdar: 'بَيَان',
        partOfSpeech: 'বিশেষণ',
        linguisticNotes: 'শব্দটি স্পষ্টতা বোঝায়।',
        confidenceNote: 'প্রচলিত অর্থের উপর ভিত্তি করে দেওয়া হয়েছে।',
      ),
    );
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
