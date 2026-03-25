import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

const _endpoint =
    'https://api.quran.com/api/v4/quran/verses/uthmani_tajweed?chapter_number=';

Future<void> main() async {
  final xmlString = await File('Resources/quran-uthmani.xml').readAsString();
  final document = XmlDocument.parse(xmlString);
  final bismillahByChapter = _loadBismillahMap(document);
  final client = http.Client();

  try {
    final chapters = <Map<String, Object?>>[];
    for (var chapter = 1; chapter <= 114; chapter += 1) {
      stdout.writeln('Fetching tajweed markup for surah $chapter...');
      final response = await client.get(Uri.parse('$_endpoint$chapter'));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to fetch surah $chapter: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final verses = (decoded['verses'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>();
      final ayahs = <Map<String, Object?>>[];

      for (final verse in verses) {
        final verseKey = verse['verse_key'] as String;
        final ayahNumber = int.parse(verseKey.split(':').last);
        final markup = verse['text_uthmani_tajweed'] as String? ?? '';
        final parsedRuns = _mergeRuns(_parseTajweedMarkup(markup));
        final displayRuns = <Map<String, Object?>>[];
        final plainText = StringBuffer();

        final bismillah = bismillahByChapter[chapter]?[ayahNumber];
        if (bismillah != null && bismillah.isNotEmpty) {
          final prefix = '${_normalizeTajweedText(bismillah)} ';
          displayRuns.add({'text': prefix, 'bucket': null});
          plainText.write(prefix);
        }

        for (final run in parsedRuns) {
          if (run.text.isEmpty) {
            continue;
          }
          final normalizedText = _normalizeTajweedText(run.text);
          displayRuns.add({
            'text': normalizedText,
            'bucket': _bucketForRawClass(run.rawClass),
          });
          plainText.write(normalizedText);
        }

        final normalizedRuns = _mergeMappedRuns(
          _applyDerivedGhunnah(
            _applyDerivedIzhar(
                _normalizeMappedRuns(_trimTrailingWhitespace(displayRuns))),
          ),
        );

        ayahs.add({
          'ayahNumber': ayahNumber,
          'plainText': _concatenateRuns(normalizedRuns),
          'runs': normalizedRuns,
        });
      }

      chapters.add({
        'surahIndex': chapter,
        'ayahs': ayahs,
      });
    }

    await File('Resources/quran-tajweed.json').writeAsString(
      jsonEncode({'chapters': chapters}),
    );
    stdout.writeln('Wrote Resources/quran-tajweed.json');
  } finally {
    client.close();
  }
}

Map<int, Map<int, String>> _loadBismillahMap(XmlDocument document) {
  return {
    for (final suraElement in document.findAllElements('sura'))
      int.parse(suraElement.getAttribute('index')!): {
        for (final ayaElement in suraElement.findElements('aya'))
          if ((ayaElement.getAttribute('bismillah') ?? '').isNotEmpty)
            int.parse(ayaElement.getAttribute('index')!):
                ayaElement.getAttribute('bismillah')!,
      },
  };
}

List<_MarkupRun> _parseTajweedMarkup(String input) {
  final runs = <_MarkupRun>[];
  var index = 0;
  String? currentClass;

  while (index < input.length) {
    if (input.startsWith('<tajweed class=', index)) {
      final end = input.indexOf('>', index);
      final rawValue = input.substring(index + 15, end).trim();
      currentClass = rawValue.replaceAll('"', '').replaceAll("'", '');
      index = end + 1;
      continue;
    }

    if (input.startsWith('</tajweed>', index)) {
      currentClass = null;
      index += 10;
      continue;
    }

    if (input.startsWith('<span class=end>', index)) {
      final end = input.indexOf('</span>', index);
      index = end == -1 ? input.length : end + 7;
      continue;
    }

    if (input.codeUnitAt(index) == 0x3C) {
      final end = input.indexOf('>', index);
      index = end == -1 ? input.length : end + 1;
      continue;
    }

    final nextTag = input.indexOf('<', index);
    final text = nextTag == -1
        ? input.substring(index)
        : input.substring(index, nextTag);
    runs.add(_MarkupRun(text: text, rawClass: currentClass));
    index = nextTag == -1 ? input.length : nextTag;
  }

  return runs;
}

List<_MarkupRun> _mergeRuns(List<_MarkupRun> runs) {
  if (runs.isEmpty) {
    return const [];
  }

  final merged = <_MarkupRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) {
      continue;
    }
    if (merged.isNotEmpty && merged.last.rawClass == run.rawClass) {
      merged[merged.length - 1] =
          merged.last.copyWith(text: '${merged.last.text}${run.text}');
      continue;
    }
    merged.add(run);
  }
  return merged;
}

List<Map<String, Object?>> _trimTrailingWhitespace(
  List<Map<String, Object?>> runs,
) {
  final normalized = runs.map((run) => Map<String, Object?>.from(run)).toList();
  while (normalized.isNotEmpty) {
    final last = normalized.last;
    final text = last['text'] as String? ?? '';
    final trimmed = text.replaceFirst(RegExp(r'\s+$'), '');
    if (trimmed.isEmpty) {
      normalized.removeLast();
      continue;
    }
    last['text'] = trimmed;
    break;
  }
  return normalized;
}

List<Map<String, Object?>> _normalizeMappedRuns(
    List<Map<String, Object?>> runs) {
  final normalized = <Map<String, Object?>>[];

  for (final run in runs) {
    final text = run['text'] as String? ?? '';
    final bucket = run['bucket'] as String?;
    for (final cluster in _splitIntoClusters(text)) {
      if (cluster.isEmpty) {
        continue;
      }

      if (_startsWithArabicMarkOrAnnotation(cluster) && normalized.isNotEmpty) {
        final previous = normalized.removeLast();
        final previousBucket = previous['bucket'] as String?;
        final attachedBucket = bucket != null &&
                (previousBucket == null || previousBucket == bucket)
            ? bucket
            : previousBucket;
        previous['text'] = '${previous['text']}$cluster';
        previous['bucket'] = attachedBucket;
        normalized.add(previous);
        continue;
      }

      normalized.add({
        'text': cluster,
        'bucket': bucket,
      });
    }
  }

  return normalized;
}

String _concatenateRuns(List<Map<String, Object?>> runs) {
  return runs.map((run) => run['text'] as String? ?? '').join();
}

String _normalizeTajweedText(String text) {
  return text.replaceAll('\u0672', '\u0670');
}

List<Map<String, Object?>> _applyDerivedIzhar(List<Map<String, Object?>> runs) {
  final clusters = <Map<String, Object?>>[];
  for (final run in runs) {
    final text = run['text'] as String? ?? '';
    final bucket = run['bucket'] as String?;
    for (final cluster in _splitIntoClusters(text)) {
      clusters.add({
        'text': cluster,
        'bucket': bucket,
      });
    }
  }

  for (var index = 0; index < clusters.length; index += 1) {
    final cluster = clusters[index];
    if (cluster['bucket'] != null) {
      continue;
    }
    final text = cluster['text'] as String? ?? '';
    if (!_isIzharSourceCluster(text)) {
      continue;
    }

    final nextBaseLetter = _nextArabicBaseLetter(clusters, index + 1);
    if (nextBaseLetter == null ||
        !_izharThroatLetters.contains(nextBaseLetter)) {
      continue;
    }

    cluster['bucket'] = 'izhar';
  }

  return clusters;
}

List<Map<String, Object?>> _applyDerivedGhunnah(
    List<Map<String, Object?>> runs) {
  return runs.map((run) {
    final text = run['text'] as String? ?? '';
    final bucket = run['bucket'] as String?;
    if (bucket != null || !_isGhunnahSourceCluster(text)) {
      return run;
    }
    return {
      'text': text,
      'bucket': 'idgham_with_ghunnah',
    };
  }).toList(growable: false);
}

List<Map<String, Object?>> _mergeMappedRuns(List<Map<String, Object?>> runs) {
  if (runs.isEmpty) {
    return const [];
  }

  final merged = <Map<String, Object?>>[];
  for (final run in runs) {
    final text = run['text'] as String? ?? '';
    if (text.isEmpty) {
      continue;
    }
    final bucket = run['bucket'] as String?;
    if (merged.isNotEmpty && merged.last['bucket'] == bucket) {
      merged.last['text'] = '${merged.last['text']}$text';
      continue;
    }
    merged.add({
      'text': text,
      'bucket': bucket,
    });
  }
  return merged;
}

List<String> _splitIntoClusters(String text) {
  final clusters = <String>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) {
      return;
    }
    clusters.add(buffer.toString());
    buffer.clear();
  }

  for (final rune in text.runes) {
    if (buffer.isEmpty) {
      buffer.writeCharCode(rune);
      continue;
    }

    if (_isArabicMarkOrAnnotation(rune)) {
      buffer.writeCharCode(rune);
      continue;
    }

    flush();
    buffer.writeCharCode(rune);
  }

  flush();
  return clusters;
}

bool _isArabicMarkOrAnnotation(int rune) {
  return (rune >= 0x064B && rune <= 0x065F) ||
      rune == 0x0670 ||
      (rune >= 0x06D6 && rune <= 0x06ED);
}

bool _startsWithArabicMarkOrAnnotation(String text) {
  if (text.isEmpty) {
    return false;
  }
  return _isArabicMarkOrAnnotation(text.runes.first);
}

bool _isIzharSourceCluster(String cluster) {
  return _isNoonSakinahCluster(cluster) || _hasTanween(cluster);
}

bool _isGhunnahSourceCluster(String cluster) {
  final baseLetter = _firstArabicBaseLetter(cluster);
  if (baseLetter != 'ن' && baseLetter != 'م') {
    return false;
  }
  return cluster.contains('\u0651');
}

bool _isNoonSakinahCluster(String cluster) {
  final baseLetter = _firstArabicBaseLetter(cluster);
  if (baseLetter != 'ن') {
    return false;
  }
  return cluster.contains('\u0652') || cluster.contains('\u06E1');
}

bool _hasTanween(String cluster) {
  return cluster.contains('\u064B') ||
      cluster.contains('\u064C') ||
      cluster.contains('\u064D');
}

String? _nextArabicBaseLetter(
  List<Map<String, Object?>> clusters,
  int startIndex,
) {
  for (var index = startIndex; index < clusters.length; index += 1) {
    final baseLetter = _firstArabicBaseLetter(
      clusters[index]['text'] as String? ?? '',
    );
    if (baseLetter != null) {
      return baseLetter;
    }
  }
  return null;
}

String? _firstArabicBaseLetter(String cluster) {
  for (final rune in cluster.runes) {
    if (_isArabicMarkOrAnnotation(rune)) {
      continue;
    }
    final char = String.fromCharCode(rune);
    if (_isArabicLetter(char)) {
      return char;
    }
    return null;
  }
  return null;
}

bool _isArabicLetter(String value) {
  final rune = value.runes.first;
  return rune >= 0x0621 && rune <= 0x064A;
}

const Set<String> _izharThroatLetters = {
  'ء',
  'أ',
  'إ',
  'ؤ',
  'ئ',
  'ه',
  'ع',
  'ح',
  'غ',
  'خ',
};

String? _bucketForRawClass(String? rawClass) {
  return switch (rawClass) {
    'ikhafa' || 'ikhafa_shafawi' => 'ikhfa',
    'ghunnah' || 'idgham_ghunnah' || 'idgham_shafawi' => 'idgham_with_ghunnah',
    'iqlab' => 'iqlab',
    'idgham_wo_ghunnah' ||
    'idgham_mutajanisayn' ||
    'idgham_mutaqaribayn' =>
      'idgham_without_ghunnah',
    'qalaqah' => 'qalqalah',
    _ => null,
  };
}

class _MarkupRun {
  const _MarkupRun({
    required this.text,
    required this.rawClass,
  });

  final String text;
  final String? rawClass;

  _MarkupRun copyWith({
    String? text,
    String? rawClass,
  }) {
    return _MarkupRun(
      text: text ?? this.text,
      rawClass: rawClass ?? this.rawClass,
    );
  }
}
