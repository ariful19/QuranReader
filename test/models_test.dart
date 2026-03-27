import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/models.dart';

void main() {
  test('mergeAyahRanges merges overlapping and adjacent ranges', () {
    final merged = mergeAyahRanges(
      const [
        AyahRange(fromAyah: 5, toAyah: 7),
        AyahRange(fromAyah: 1, toAyah: 2),
        AyahRange(fromAyah: 3, toAyah: 4),
        AyahRange(fromAyah: 7, toAyah: 9),
      ],
    );

    expect(merged, hasLength(1));
    expect(merged.first.fromAyah, 1);
    expect(merged.first.toAyah, 9);
  });

  test('splitQuranTextRuns isolates Quran-specific annotation signs', () {
    const source = 'وَدُّوا۟ لَوْ تُدْهِنُ فَيُدْهِنُونَ ۞ عُتُلٍّۭ';
    final runs = splitQuranTextRuns(source);

    expect(runs.map((run) => run.text).join(), source);
    expect(runs.where((run) => run.isAnnotation).map((run) => run.text), [
      '۟',
      '۞',
      'ۭ',
    ]);
  });

  test(
      'normalizeTajweedRunsForDisplay moves the base letter with leading marks',
      () {
    final normalized = normalizeTajweedRunsForDisplay([
      const TajweedRun(text: '\u0644'),
      const TajweedRun(
        text: '\u0651\u0650\u0644\u0652\u0645\u064f',
        bucket: TajweedLegendBucket.idghamWithGhunnah,
      ),
    ]);

    expect(normalized, hasLength(1));
    expect(normalized.single.bucket, TajweedLegendBucket.idghamWithGhunnah);
    expect(
        normalized.single.text, '\u0644\u0651\u0650\u0644\u0652\u0645\u064f');
  });

  test('suggestedRangeForTappedAyah follows the nearest unfinished gap', () {
    final firstSuggestion = suggestedRangeForTappedAyah(
      savedRanges: const [],
      tappedAyah: 12,
    );
    expect(firstSuggestion.fromAyah, 1);
    expect(firstSuggestion.toAyah, 12);

    final secondSuggestion = suggestedRangeForTappedAyah(
      savedRanges: const [AyahRange(fromAyah: 1, toAyah: 12)],
      tappedAyah: 20,
    );
    expect(secondSuggestion.fromAyah, 13);
    expect(secondSuggestion.toAyah, 20);

    final thirdSuggestion = suggestedRangeForTappedAyah(
      savedRanges: const [
        AyahRange(fromAyah: 1, toAyah: 20),
        AyahRange(fromAyah: 30, toAyah: 40),
      ],
      tappedAyah: 25,
    );
    expect(thirdSuggestion.fromAyah, 21);
    expect(thirdSuggestion.toAyah, 25);
  });

  test('persisted state falls back to default reader settings', () {
    final state = PersistedState.fromJson(
      const {
        'orderMode': 'normal',
        'progressBySurah': <String, Object?>{},
        'goalState': null,
      },
    );

    expect(state.readerSettings.fontSize, ReaderSettings.defaultFontSize);
    expect(
      state.readerSettings.backgroundKey,
      ReaderSettings.defaultBackgroundKey,
    );
    expect(
      state.readerSettings.tajweedEnabled,
      ReaderSettings.defaultTajweedEnabled,
    );
    expect(state.lastReadAyahBySurah, isEmpty);
  });

  test('reader settings round-trip tajweed preference', () {
    const settings = ReaderSettings(
      fontSize: 35,
      backgroundKey: 'mist',
      tajweedEnabled: true,
    );

    final restored = ReaderSettings.fromJson(settings.toJson());

    expect(restored.fontSize, 35);
    expect(restored.backgroundKey, 'mist');
    expect(restored.tajweedEnabled, isTrue);
  });

  test('persisted state round-trips last saved range bookmark', () {
    const state = PersistedState(
      orderMode: SurahOrderMode.normal,
      progressBySurah: {},
      goalState: null,
      readerSettings: ReaderSettings.defaults,
      lastSavedRangeBookmark: LastSavedRangeBookmark(
        surahIndex: 2,
        fromAyah: 5,
        toAyah: 7,
      ),
      lastReadAyahBySurah: {2: 6},
    );

    final restored = PersistedState.fromJson(state.toJson());

    expect(restored.lastSavedRangeBookmark, isNotNull);
    expect(restored.lastSavedRangeBookmark!.surahIndex, 2);
    expect(restored.lastSavedRangeBookmark!.fromAyah, 5);
    expect(restored.lastSavedRangeBookmark!.toAyah, 7);
    expect(restored.lastReadAyahBySurah, {2: 6});
  });
}
