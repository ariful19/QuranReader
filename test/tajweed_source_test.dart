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

  test('parseTajweedSourceJson normalizes upstream alef codepoint for display', () {
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
}
