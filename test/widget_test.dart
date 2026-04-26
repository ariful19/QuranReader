import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/app_controller.dart';
import 'package:quran_reader/src/home_page.dart';
import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/progress_repository.dart';
import 'package:quran_reader/src/quran_repository.dart';
import 'package:quran_reader/src/reader_page.dart';

const _expectedBasmalaText = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِيمِ';

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

  test('resetAllProgress clears remembered last-read ayahs', () async {
    final controller = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: _MemoryStateStore(),
    );
    await controller.load();

    await controller.saveLastReadAyah(surahIndex: 1, ayahNumber: 7);
    expect(controller.lastReadAyahFor(1), 7);

    await controller.resetAllProgress();

    expect(controller.lastReadAyahFor(1), isNull);
  });

  testWidgets('opens reader and saves a tapped ayah range', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final textTopLeft = tester.getTopLeft(
      find.byKey(const Key('continuous-ayah-text')),
    );
    await tester.tapAt(textTopLeft + const Offset(72, 150));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-range-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-range-button')));
    await tester.pumpAndSettle();

    expect(controller.rangesFor(1), hasLength(1));
    expect(controller.lastSavedRangeBookmark, isNotNull);
    expect(controller.lastSavedRangeBookmark!.toAyah, greaterThanOrEqualTo(1));
  });

  testWidgets('reader opens fullscreen and shows progress in a dialog',
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

    expect(find.byKey(const Key('reader-progress-card')), findsNothing);
    expect(find.byKey(const Key('reader-progress-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-settings-button')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-font-size-slider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader-background-midnight')));
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

    final fullscreenProgressBefore = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('reader-fullscreen-scroll-progress')),
    );
    expect(fullscreenProgressBefore.value, 0);

    await tester.drag(
      find.byKey(const Key('reader-scroll-view')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();

    final fullscreenProgressAfter = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('reader-fullscreen-scroll-progress')),
    );
    expect(fullscreenProgressAfter.value ?? 0, greaterThan(0));

    await tester.tap(find.byKey(const Key('reader-progress-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-progress-card')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('close-reader-progress-dialog-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-progress-card')), findsNothing);
  });

  testWidgets('reader shows a basmala header for surahs other than 1 and 9',
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

    expect(find.byKey(const Key('reader-basmala-header')), findsOneWidget);
    expect(find.text(_expectedBasmalaText), findsOneWidget);
  });

  testWidgets('reader omits the basmala header for surahs 1 and 9',
      (tester) async {
    final controller = QuranAppController(
      catalogSource: const _StaticCatalogSource([
        SurahData(
          index: 1,
          arabicName: 'الفاتحة',
          englishName: 'The Opening',
          chronologicalOrder: 5,
          totalUnicodeChars: 24,
          ayahs: [
            AyahData(number: 1, text: 'بِسۡمِ ٱللَّهِ'),
            AyahData(number: 2, text: 'ٱلۡحَمۡدُ لِلَّهِ'),
          ],
        ),
        SurahData(
          index: 9,
          arabicName: 'التوبة',
          englishName: 'The Repentance',
          chronologicalOrder: 113,
          totalUnicodeChars: 24,
          ayahs: [
            AyahData(number: 1, text: 'بَرَآءَةٞ مِّنَ ٱللَّهِ'),
            AyahData(number: 2, text: 'فَسِيحُواْ فِي ٱلۡأَرۡضِ'),
          ],
        ),
      ]),
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
    expect(find.byKey(const Key('reader-basmala-header')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 9,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-basmala-header')), findsNothing);
  });

  testWidgets('saving a later custom range and closing dialog does not assert',
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

  testWidgets('saved range navigation works from the progress dialog',
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

    await tester.tap(find.byKey(const Key('reader-progress-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('range-chip-2-8')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollViewAfter = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    final scrolledOffset = scrollViewAfter.controller!.offset;
    expect(scrolledOffset, greaterThan(0));
    expect(find.byKey(const Key('reader-progress-card')), findsNothing);
  });

  testWidgets('reader swipe shorter than half the screen does not navigate',
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
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-1-1')), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
  });

  testWidgets('reader swipe left to right opens the next surah',
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
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(220, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-2-1')), findsOneWidget);
    expect(find.text('The Cow'), findsOneWidget);
  });

  testWidgets(
      'reader swipe keeps the basmala below the toolbar without saved progress',
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
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 32),
            viewPadding: EdgeInsets.only(top: 32),
          ),
          child: SurahReaderPage(
            controller: controller,
            surahIndex: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(220, 0),
    );
    await tester.pumpAndSettle();

    final basmalaRect = tester.getRect(
      find.byKey(const Key('reader-basmala-header')),
    );
    final progressButtonRect = tester.getRect(
      find.byKey(const Key('reader-progress-button')),
    );

    expect(basmalaRect.top, greaterThan(progressButtonRect.bottom));
  });

  testWidgets('reader swipe right to left opens the previous surah',
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
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-1-1')), findsOneWidget);
    expect(find.text('The Opening'), findsOneWidget);
  });

  testWidgets('reader tap zones page with two-line overlap', (tester) async {
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
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(initialScrollView.controller!.offset, 0);

    await tester.tap(find.byKey(const Key('reader-page-down-zone')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final downScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    const expectedOverlap = ReaderSettings.defaultFontSize * 1.85 * 2;
    final expectedOffset =
        downScrollView.controller!.position.viewportDimension - expectedOverlap;
    expect(downScrollView.controller!.offset, closeTo(expectedOffset, 40));

    await tester.tap(find.byKey(const Key('reader-page-up-zone')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final upScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(upScrollView.controller!.offset, closeTo(0, 8));
  });

  testWidgets('swiping keeps the next surah in the fullscreen reader',
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
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-swipe-area')),
      const Offset(220, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ayah-2-1')), findsOneWidget);
    expect(find.byKey(const Key('reader-progress-card')), findsNothing);
    expect(find.byKey(const Key('reader-progress-button')), findsOneWidget);
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

  testWidgets('home surah tiles resume the remembered ayah after reopening',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemoryStateStore();
    final firstController = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: store,
    );
    await firstController.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: firstController),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('surah-tile-1')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('reader-scroll-view')),
      const Offset(0, -650),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(firstController.lastReadAyahFor(1), greaterThan(1));

    await tester.pageBack();
    await tester.pumpAndSettle();

    final secondController = QuranAppController(
      catalogSource: _FakeCatalogSource(),
      appStateStore: store,
    );
    await secondController.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: QuranHomePage(controller: secondController),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('surah-tile-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollView.controller!.offset, greaterThan(0));
  });

  testWidgets('explicit initial ayah overrides remembered resume state',
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
    await controller.saveLastReadAyah(surahIndex: 2, ayahNumber: 2);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SurahReaderPage(
          controller: controller,
          surahIndex: 2,
          initialAyahNumber: 10,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reader-scroll-view')),
    );
    expect(scrollView.controller!.offset, greaterThan(0));
    expect(controller.lastReadAyahFor(2), greaterThan(5));
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

class _StaticCatalogSource implements CatalogSource {
  const _StaticCatalogSource(this.catalog);

  final List<SurahData> catalog;

  @override
  Future<List<SurahData>> loadCatalog() async => catalog;
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
