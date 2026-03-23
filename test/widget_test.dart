import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/app_controller.dart';
import 'package:quran_reader/src/home_page.dart';
import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/progress_repository.dart';
import 'package:quran_reader/src/quran_repository.dart';
import 'package:quran_reader/src/reader_page.dart';

void main() {
  testWidgets('opens reader and saves a tapped ayah range', (tester) async {
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
  });

  testWidgets('reader settings and fullscreen mode update the reader',
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
