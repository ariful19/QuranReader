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

  test('parseTajweedSourceJson normalizes upstream alef codepoint for display',
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
    expect(ayah!.plainText, 'ذَٰلِكَ ٱلصَّلَوٰةَ');
    expect(ayah.runs.first.text, 'ذَٰلِكَ');
    expect(ayah.runs.last.text, ' ٱلصَّلَوٰةَ');
  });

  test('parseTajweedSourceJson derives ghunnah for mushaddad noon and meem',
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
    expect(
      ayah!.runs
          .where((run) => run.bucket == TajweedLegendBucket.idghamWithGhunnah),
      isNotEmpty,
    );
    expect(
      ayah.runs.any(
        (run) =>
            run.bucket == TajweedLegendBucket.idghamWithGhunnah &&
            run.text.contains('مَّ'),
      ),
      isTrue,
    );
    expect(
      ayah.runs.any(
        (run) =>
            run.bucket == TajweedLegendBucket.idghamWithGhunnah &&
            run.text.contains('نَّ'),
      ),
      isTrue,
    );
  });

  test(
      'parseTajweedSourceJson keeps leading marks with the prior colored cluster',
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
      ayah!.runs.any(
        (run) =>
            run.bucket == TajweedLegendBucket.idghamWithGhunnah &&
            run.text.contains('مِّ'),
      ),
      isTrue,
    );
    expect(
      ayah.runs.any(
        (run) =>
            run.bucket == TajweedLegendBucket.idghamWithoutGhunnah &&
            run.text.contains('رَّ'),
      ),
      isTrue,
    );
  });
}
