import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/quran_repository.dart';
import 'package:quran_reader/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled SQLite Quran source', () async {
    final catalog = await const AssetQuranCatalogSource().loadCatalog();
    final tajweed = await const AssetTajweedSource().loadTajweed();

    expect(catalog, hasLength(114));
    expect(catalog.first.arabicName, 'الفاتحة');
    expect(catalog.first.englishName, 'The Opening');
    expect(catalog.first.ayahCount, 7);
    expect(
      catalog.fold<int>(0, (sum, surah) => sum + surah.ayahCount),
      6236,
    );
    expect(
      catalog.first.ayahs.first.text,
      'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِيمِ',
    );
    expect(tajweed[1]?[1]?.plainText, catalog.first.ayahs.first.text);
    expect(tajweed[2]?[255], isNotNull);
  });

  test('builds plain ayah text from DB words and drops trailing ayah digits',
      () {
    final ayah = buildQpcTajweedAyahData(
      ayahNumber: 1,
      wordMarkup: const [
        'بِسۡمِ',
        '<rule class=ham_wasl>ٱ</rule>للَّهِ',
        '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّحۡمَ<rule class=madda_normal>ـٰ</rule>نِ',
        '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّح<rule class=madda_permissible>ِي</rule>مِ',
        '١',
      ],
    );

    expect(ayah.plainText, 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِيمِ');
    expect(ayah.runs.map((run) => run.text).join(), ayah.plainText);
    expect(ayah.plainText, isNot(contains('١')));
  });

  test('maps supported DB rule classes to existing tajweed buckets', () {
    final ayah = buildQpcTajweedAyahData(
      ayahNumber: 6,
      wordMarkup: const [
        'مِنَ',
        '<rule class=ham_wasl>ٱ</rule>لۡجِ<rule class=ghunnah>نّ</rule>َةِ',
        'وَ<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule><rule class=ghunnah>نّ</rule><rule class=madda_permissible>َا</rule>سِ',
        '٦',
      ],
    );

    expect(ayah.plainText, 'مِنَ ٱلۡجِنَّةِ وَٱلنَّاسِ');
    expect(
      ayah.runs
          .where(
            (run) => run.bucket == TajweedLegendBucket.idghamWithGhunnah,
          )
          .map((run) => run.text),
      containsAll(const ['نّ', 'نّ']),
    );
    expect(ayah.runs.map((run) => run.text).join(), ayah.plainText);
  });
}
