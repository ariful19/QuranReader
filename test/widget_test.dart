import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/app_controller.dart';
import 'package:quran_reader/src/home_page.dart';
import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/progress_repository.dart';
import 'package:quran_reader/src/quran_repository.dart';
import 'package:quran_reader/src/reader_page.dart';

void main() {
  test('removing the bookmarked merged range clears the last saved bookmark',
      () async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await controller.saveRange(
      surah: controller.surahByIndex(1),
      fromAyah: 2,
      toAyah: 8,
    );
    expect(controller.lastSavedRangeBookmark, isNotNull);

    await controller.removeRangeAt(1, 0);

    expect(controller.lastSavedRangeBookmark, isNull);
  });

  testWidgets('opens reader and saves a tapped ayah range', (tester) async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      tajweedSource: const _FakeTajweedSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('surah-tile-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('surah-tile-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-1-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ayah-1-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-range-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-range-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ayah 1 to 1'), findsWidgets);
    expect(controller.rangesFor(1), hasLength(1));
    expect(controller.lastSavedRangeBookmark, isNotNull);
    expect(controller.lastSavedRangeBookmark!.toAyah, 1);
  });

  testWidgets('reader settings and fullscreen mode update the reader',
      (tester) async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      tajweedSource: const _FakeTajweedSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('surah-tile-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader-settings-button')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-font-size-slider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader-background-midnight')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reader-tajweed-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader-tajweed-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-reader-settings-button')));
    await tester.pumpAndSettle();

    expect(controller.readerSettings.backgroundKey, 'midnight');
    expect(controller.readerSettings.fontSize, greaterThan(33));
    expect(controller.readerSettings.tajweedEnabled, isTrue);
    final readerRichText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((candidate) => candidate.textAlign == TextAlign.justify);
    expect(
      readerRichText.text.toPlainText(),
      contains('tajweed sample 1'),
    );

    expect(find.byKey(const Key('reader-progress-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-fullscreen-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-progress-card')), findsNothing);
    expect(
      find.byKey(const Key('reader-exit-fullscreen-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reader-exit-fullscreen-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-progress-card')), findsOneWidget);
  });

  testWidgets('saving a later custom range and closing dialog does not assert',
      (tester) async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('surah-tile-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ayah-1-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-range-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ayah-1-3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('from-ayah-field')), '3');
    await tester.enterText(find.byKey(const Key('to-ayah-field')), '3');
    await tester.tap(find.byKey(const Key('save-range-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ayah 3 to 3'), findsWidgets);

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.rangesFor(1), hasLength(2));
    expect(controller.rangesFor(1).first.fromAyah, 1);
    expect(controller.rangesFor(1).first.toAyah, 1);
    expect(controller.rangesFor(1).last.fromAyah, 3);
    expect(controller.rangesFor(1).last.toAyah, 3);
  });

  testWidgets('saved range navigation survives fullscreen toggles',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();
    await controller.saveRange(
      surah: controller.surahByIndex(1),
      fromAyah: 2,
      toAyah: 8,
    );

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

    final scrollViewBefore = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollViewBefore.controller!.offset, 0);

    await tester.tap(find.byKey(const Key('range-chip-2-8')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollViewAfter = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    final scrolledOffset = scrollViewAfter.controller!.offset;
    expect(scrolledOffset, greaterThan(0));

    await tester.tap(find.byKey(const Key('reader-fullscreen-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollViewFullscreen = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollViewFullscreen.controller!.offset, greaterThan(0));

    await tester.tap(find.byKey(const Key('reader-exit-fullscreen-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollViewRestored = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollViewRestored.controller!.offset, greaterThan(0));
  });

  testWidgets('reader swipe left to right opens the next surah',
      (tester) async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
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

    await tester.fling(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(400, 0),
      1500,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-2-1')), findsOneWidget);
    expect(find.text('The Cow'), findsOneWidget);
  });

  testWidgets('reader swipe right to left opens the previous surah',
      (tester) async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(-400, 0),
      1500,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-1-1')), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
  });

  testWidgets('home jump dialog resumes the globally bookmarked saved range',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();
    await controller.saveRange(
      surah: controller.surahByIndex(1),
      fromAyah: 2,
      toAyah: 8,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jump-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jump-last-saved-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollView.controller!.offset, greaterThan(0));
  });

  testWidgets('home jump dialog manually jumps to a specific ayah',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jump-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('jump-surah-field')), '2');
    await tester.enterText(find.byKey(const Key('jump-ayah-field')), '10');
    await tester.tap(find.byKey(const Key('jump-manual-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollView.controller!.offset, greaterThan(0));
    expect(find.byKey(const Key('ayah-2-10')), findsOneWidget);
  });

  testWidgets('manual jump validates ayah numbers against the selected surah',
      (tester) async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jump-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('jump-surah-field')), '2');
    await tester.enterText(find.byKey(const Key('jump-ayah-field')), '99');
    await tester.tap(find.byKey(const Key('jump-manual-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter an ayah number from 1 to 12.'),
      findsOneWidget,
    );
    expect(find.byType(SurahReaderPage), findsNothing);
  });
}

class _FakeCatalogSource implements CatalogSource {
  @override
  Future<List<SurahData>> loadCatalog() async {
    return [
      SurahData(
        index: 1,
        arabicName: 'الفاتحة',
        englishName: 'The Opening',
        chronologicalOrder: 5,
        totalUnicodeChars: 240,
        ayahs: List.generate(
          20,
          (index) => AyahData(
            number: index + 1,
            text: 'اية ${index + 1} من سورة الاختبار',
          ),
        ),
      ),
      SurahData(
        index: 2,
        arabicName: 'البقرة',
        englishName: 'The Cow',
        chronologicalOrder: 87,
        totalUnicodeChars: 180,
        ayahs: List.generate(
          12,
          (index) => AyahData(
            number: index + 1,
            text: 'آية ${index + 1} من سورة البقرة',
          ),
        ),
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

class _FakeTajweedSource implements TajweedSource {
  const _FakeTajweedSource();

  @override
  Future<Map<int, Map<int, TajweedAyahData>>> loadTajweed() async {
    return {
      1: {
        for (var ayahNumber = 1; ayahNumber <= 20; ayahNumber += 1)
          ayahNumber: TajweedAyahData(
            ayahNumber: ayahNumber,
            plainText: ayahNumber == 1
                ? 'tajweed sample 1'
                : 'Ø§ÙŠØ© $ayahNumber Ù…Ù† Ø³ÙˆØ±Ø© Ø§Ù„Ø§Ø®ØªØ¨Ø§Ø±',
            runs: [
              TajweedRun(
                text: ayahNumber == 1 ? 'tajweed ' : 'Ø§ÙŠØ© ',
                bucket: ayahNumber == 1
                    ? TajweedLegendBucket.idghamWithGhunnah
                    : null,
              ),
              TajweedRun(
                text: ayahNumber == 1
                    ? 'sample 1'
                    : '$ayahNumber Ù…Ù† Ø³ÙˆØ±Ø© Ø§Ù„Ø§Ø®ØªØ¨Ø§Ø±',
              ),
            ],
          ),
      },
    };
  }
}
