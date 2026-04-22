import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/quran_repository.dart';

void main() {
  test('buildQpcTajweedAyahData maps DB rule classes to existing buckets', () {
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
    expect(ayah.runs.map((run) => run.text).join(), ayah.plainText);
    expect(
      ayah.runs
          .where(
            (run) => run.bucket == TajweedLegendBucket.idghamWithGhunnah,
          )
          .map((run) => run.text),
      containsAll(const ['نّ', 'نّ']),
    );
  });

  test('buildQpcTajweedAyahData preserves source codepoints exactly', () {
    final ayah = buildQpcTajweedAyahData(
      ayahNumber: 2,
      wordMarkup: const [
        'ذَٲلِكَ',
        '<rule class=ikhafa>ٱلصَّلَوٲةَ</rule>',
        '٢',
      ],
    );

    expect(ayah.plainText, 'ذَٲلِكَ ٱلصَّلَوٲةَ');
    expect(ayah.runs[0].text, 'ذَٲلِكَ');
    expect(ayah.runs[1].text, ' ');
    expect(ayah.runs[2].text, 'ٱلصَّلَوٲةَ');
    expect(ayah.runs[2].bucket, TajweedLegendBucket.ikhfa);
  });

  test('buildQpcTajweedAyahData leaves unsupported DB classes uncolored', () {
    final ayah = buildQpcTajweedAyahData(
      ayahNumber: 1,
      wordMarkup: const [
        '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>حَمْدُ',
        '١',
      ],
    );

    expect(ayah.runs, hasLength(3));
    expect(ayah.runs[0].text, 'ٱ');
    expect(ayah.runs[0].bucket, isNull);
    expect(ayah.runs[1].text, 'ل');
    expect(ayah.runs[1].bucket, isNull);
    expect(ayah.runs[2].text, 'حَمْدُ');
    expect(ayah.runs[2].bucket, isNull);
  });

  test('buildQpcTajweedAyahData preserves source run boundaries', () {
    final ayah = buildQpcTajweedAyahData(
      ayahNumber: 5,
      wordMarkup: const [
        '<rule class=idgham_ghunnah>هُدًى م</rule>ّ<rule class=idgham_wo_ghunnah>ِن ر</rule>َّبِّهِمْ',
        '٥',
      ],
    );

    expect(ayah.runs, hasLength(4));
    expect(ayah.runs[0].text, 'هُدًى م');
    expect(
      ayah.runs[0].bucket,
      TajweedLegendBucket.idghamWithGhunnah,
    );
    expect(ayah.runs[1].text, 'ّ');
    expect(ayah.runs[1].bucket, isNull);
    expect(ayah.runs[2].text, 'ِن ر');
    expect(
      ayah.runs[2].bucket,
      TajweedLegendBucket.idghamWithoutGhunnah,
    );
    expect(ayah.runs[3].text, 'َّبِّهِمْ');
    expect(ayah.runs[3].bucket, isNull);
  });
}
