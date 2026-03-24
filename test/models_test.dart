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
  });
}
