import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/quran_repository.dart';

void main() {
  test('parseTajweedSourceJson loads chapter ayah runs and buckets', () {
    const json = '''
{
  "chapters": [
    {
      "surahIndex": 1,
      "ayahs": [
        {
          "ayahNumber": 1,
          "plainText": "abc",
          "runs": [
            {"text": "a", "bucket": "ikhfa"},
            {"text": "bc", "bucket": null}
          ]
        }
      ]
    }
  ]
}
''';

    final parsed = parseTajweedSourceJson(json);
    final ayah = parsed[1]?[1];

    expect(ayah, isNotNull);
    expect(ayah!.plainText, 'abc');
    expect(ayah.runs, hasLength(2));
    expect(ayah.runs.first.bucket, TajweedLegendBucket.ikhfa);
    expect(ayah.runs.last.bucket, isNull);
  });

  test('parseTajweedSourceJson preserves source codepoints exactly',
      () {
    const json = '''
{
  "chapters": [
    {
      "surahIndex": 2,
      "ayahs": [
        {
          "ayahNumber": 2,
          "plainText": "ذَٲلِكَ ٱلصَّلَوٲةَ",
          "runs": [
            {"text": "ذَٲلِكَ", "bucket": null},
            {"text": " ٱلصَّلَوٲةَ", "bucket": "ikhfa"}
          ]
        }
      ]
    }
  ]
}
''';

    final parsed = parseTajweedSourceJson(json);
    final ayah = parsed[2]?[2];

    expect(ayah, isNotNull);
    expect(ayah!.plainText, 'ذَٲلِكَ ٱلصَّلَوٲةَ');
    expect(ayah.runs.first.text, 'ذَٲلِكَ');
    expect(ayah.runs.last.text, ' ٱلصَّلَوٲةَ');
  });

  test('parseTajweedSourceJson keeps source buckets untouched',
      () {
    const json = '''
{
  "chapters": [
    {
      "surahIndex": 1,
      "ayahs": [
        {
          "ayahNumber": 2,
          "plainText": "مَّا نَّحْنُ",
          "runs": [
            {"text": "مَّا نَّحْنُ", "bucket": null}
          ]
        }
      ]
    }
  ]
}
''';

    final parsed = parseTajweedSourceJson(json);
    final ayah = parsed[1]?[2];

    expect(ayah, isNotNull);
    expect(ayah!.runs, hasLength(1));
    expect(ayah.runs.single.bucket, isNull);
    expect(ayah.runs.single.text, 'مَّا نَّحْنُ');
  });

  test('parseTajweedSourceJson preserves run boundaries around leading marks',
      () {
    const json = '''
{
  "chapters": [
    {
      "surahIndex": 2,
      "ayahs": [
        {
          "ayahNumber": 5,
          "plainText": "هُدًى مِّن رَّبِّهِمْ",
          "runs": [
            {"text": "هُدًى م", "bucket": "idgham_with_ghunnah"},
            {"text": "ّ", "bucket": null},
            {"text": "ِن ر", "bucket": "idgham_without_ghunnah"},
            {"text": "َّبِّهِمْ", "bucket": null}
          ]
        }
      ]
    }
  ]
}
''';

    final parsed = parseTajweedSourceJson(json);
    final ayah = parsed[2]?[5];

    expect(ayah, isNotNull);
    expect(
      ayah!.runs,
      hasLength(4),
    );
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
