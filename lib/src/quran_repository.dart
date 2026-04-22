import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;

import 'models.dart';
import 'surah_metadata.dart';

abstract class CatalogSource {
  Future<List<SurahData>> loadCatalog();
}

abstract class TajweedSource {
  Future<Map<int, Map<int, TajweedAyahData>>> loadTajweed();
}

class AssetQuranCatalogSource implements CatalogSource {
  const AssetQuranCatalogSource({
    this.assetPath = 'Resources/qpc-hafs-tajweed.db',
  });

  final String assetPath;

  @override
  Future<List<SurahData>> loadCatalog() async {
    final bundle = await _loadQpcHafsTajweedBundle(assetPath);
    return bundle.catalog;
  }
}

class EmptyTajweedSource implements TajweedSource {
  const EmptyTajweedSource();

  @override
  Future<Map<int, Map<int, TajweedAyahData>>> loadTajweed() async {
    return const {};
  }
}

class AssetTajweedSource implements TajweedSource {
  const AssetTajweedSource({
    this.assetPath = 'Resources/qpc-hafs-tajweed.db',
  });

  final String assetPath;

  @override
  Future<Map<int, Map<int, TajweedAyahData>>> loadTajweed() async {
    final bundle = await _loadQpcHafsTajweedBundle(assetPath);
    return bundle.tajweedBySurah;
  }
}

final Map<String, Future<_QpcHafsTajweedBundle>> _bundleCache = {};

Future<_QpcHafsTajweedBundle> _loadQpcHafsTajweedBundle(String assetPath) {
  return _bundleCache.putIfAbsent(
    assetPath,
    () async {
      final databaseFactory = _databaseFactoryForCurrentPlatform();
      final databasePath = await _materializeAssetDatabase(
        assetPath,
        databaseFactory,
      );
      final database = await databaseFactory.openDatabase(
        databasePath,
        options: sqflite.OpenDatabaseOptions(readOnly: true),
      );
      try {
        final rows = await database.query(
          'words',
          columns: ['surah', 'ayah', 'word', 'text'],
          orderBy: 'surah ASC, ayah ASC, word ASC',
        );
        return _buildQpcHafsTajweedBundle(rows);
      } finally {
        await database.close();
      }
    },
  );
}

sqflite.DatabaseFactory _databaseFactoryForCurrentPlatform() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqflite_ffi.sqfliteFfiInit();
    return sqflite_ffi.databaseFactoryFfi;
  }
  return sqflite.databaseFactory;
}

Future<String> _materializeAssetDatabase(
  String assetPath,
  sqflite.DatabaseFactory databaseFactory,
) async {
  final bytes = await rootBundle.load(assetPath);
  final databasesPath = await databaseFactory.getDatabasesPath();
  final databasePath = path.join(databasesPath, path.basename(assetPath));
  final databaseFile = File(databasePath);
  await databaseFile.parent.create(recursive: true);
  await databaseFile.writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    flush: true,
  );
  return databasePath;
}

_QpcHafsTajweedBundle _buildQpcHafsTajweedBundle(
  Iterable<Map<String, Object?>> rows,
) {
  final ayahsBySurah = <int, List<AyahData>>{};
  final tajweedBySurah = <int, Map<int, TajweedAyahData>>{};

  int? currentSurah;
  int? currentAyah;
  final currentWords = <String>[];

  void flushAyah() {
    final surahIndex = currentSurah;
    final ayahNumber = currentAyah;
    if (surahIndex == null || ayahNumber == null) {
      return;
    }

    final tajweedAyah = buildQpcTajweedAyahData(
      ayahNumber: ayahNumber,
      wordMarkup: currentWords,
    );
    ayahsBySurah.putIfAbsent(surahIndex, () => <AyahData>[]).add(
          AyahData(
            number: ayahNumber,
            text: tajweedAyah.plainText,
          ),
        );
    tajweedBySurah.putIfAbsent(
      surahIndex,
      () => <int, TajweedAyahData>{},
    )[ayahNumber] = tajweedAyah;
    currentWords.clear();
  }

  for (final row in rows) {
    final surahIndex = row['surah'] as int? ?? 0;
    final ayahNumber = row['ayah'] as int? ?? 0;
    final wordText = row['text'] as String? ?? '';

    if (currentSurah != surahIndex || currentAyah != ayahNumber) {
      flushAyah();
      currentSurah = surahIndex;
      currentAyah = ayahNumber;
    }
    currentWords.add(wordText);
  }
  flushAyah();

  final catalog = <SurahData>[];
  final sortedSurahIndexes = ayahsBySurah.keys.toList()..sort();
  for (final surahIndex in sortedSurahIndexes) {
    final seed = surahSeeds[surahIndex];
    if (seed == null) {
      throw StateError('Missing metadata seed for surah $surahIndex.');
    }
    final arabicName = surahArabicNames[surahIndex];
    if (arabicName == null) {
      throw StateError('Missing Arabic metadata for surah $surahIndex.');
    }

    final ayahs = List<AyahData>.unmodifiable(ayahsBySurah[surahIndex]!);
    final totalUnicodeChars = ayahs.fold<int>(
      0,
      (sum, ayah) => sum + ayah.unicodeChars,
    );
    catalog.add(
      SurahData(
        index: surahIndex,
        arabicName: arabicName,
        englishName: seed.englishName,
        chronologicalOrder: seed.chronologicalOrder,
        ayahs: ayahs,
        totalUnicodeChars: totalUnicodeChars,
      ),
    );
  }

  if (catalog.length != 114) {
    throw StateError(
      'Expected 114 surahs in the bundled DB but found ${catalog.length}.',
    );
  }

  final totalAyahs = catalog.fold<int>(
    0,
    (sum, surah) => sum + surah.ayahCount,
  );
  if (totalAyahs != 6236) {
    throw StateError('Expected 6236 ayahs but found $totalAyahs.');
  }

  return _QpcHafsTajweedBundle(
    catalog: List<SurahData>.unmodifiable(catalog),
    tajweedBySurah: {
      for (final entry in tajweedBySurah.entries)
        entry.key: Map<int, TajweedAyahData>.unmodifiable(entry.value),
    },
  );
}

@visibleForTesting
TajweedAyahData buildQpcTajweedAyahData({
  required int ayahNumber,
  required Iterable<String> wordMarkup,
}) {
  final parsedWords = wordMarkup
      .map(
        (markup) => _ParsedWordMarkup(
          markup: markup,
          plainText: _stripRuleMarkup(markup),
        ),
      )
      .where((word) => word.plainText.isNotEmpty)
      .toList(growable: true);

  if (parsedWords.isNotEmpty &&
      parsedWords.last.plainText == _toArabicIndicDigits(ayahNumber)) {
    parsedWords.removeLast();
  }

  final plainText = parsedWords.map((word) => word.plainText).join(' ');
  final runs = <TajweedRun>[];
  for (var index = 0; index < parsedWords.length; index += 1) {
    if (index > 0) {
      runs.add(const TajweedRun(text: ' '));
    }

    final wordRuns = _parseRuleMarkup(parsedWords[index].markup);
    for (final run in wordRuns) {
      if (run.text.isEmpty) {
        continue;
      }
      runs.add(
        TajweedRun(
          text: run.text,
          bucket: _bucketForRawClass(run.rawClass),
        ),
      );
    }
  }

  return TajweedAyahData(
    ayahNumber: ayahNumber,
    plainText: plainText,
    runs: List<TajweedRun>.unmodifiable(
      runs.isEmpty && plainText.isNotEmpty
          ? [TajweedRun(text: plainText)]
          : runs,
    ),
  );
}

String _stripRuleMarkup(String input) {
  return _parseRuleMarkup(input).map((run) => run.text).join();
}

List<_RuleMarkupRun> _parseRuleMarkup(String input) {
  final runs = <_RuleMarkupRun>[];
  var index = 0;
  String? currentClass;

  while (index < input.length) {
    if (input.startsWith('<rule', index)) {
      final end = input.indexOf('>', index);
      if (end == -1) {
        break;
      }
      final tag = input.substring(index, end + 1);
      currentClass = _extractRuleClass(tag);
      index = end + 1;
      continue;
    }

    if (input.startsWith('</rule>', index)) {
      currentClass = null;
      index += 7;
      continue;
    }

    if (input.codeUnitAt(index) == 0x3C) {
      final end = input.indexOf('>', index);
      if (end == -1) {
        break;
      }
      index = end + 1;
      continue;
    }

    final nextTag = input.indexOf('<', index);
    final text = nextTag == -1
        ? input.substring(index)
        : input.substring(index, nextTag);
    runs.add(_RuleMarkupRun(text: text, rawClass: currentClass));
    index = nextTag == -1 ? input.length : nextTag;
  }

  return _mergeRuleMarkupRuns(runs);
}

List<_RuleMarkupRun> _mergeRuleMarkupRuns(List<_RuleMarkupRun> runs) {
  if (runs.isEmpty) {
    return const [];
  }

  final merged = <_RuleMarkupRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) {
      continue;
    }
    if (merged.isNotEmpty && merged.last.rawClass == run.rawClass) {
      merged[merged.length - 1] = merged.last.copyWith(
        text: '${merged.last.text}${run.text}',
      );
      continue;
    }
    merged.add(run);
  }
  return merged;
}

String? _extractRuleClass(String tag) {
  final match = _ruleClassPattern.firstMatch(tag);
  if (match == null) {
    return null;
  }
  return match.group(1) ?? match.group(2) ?? match.group(3);
}

String _toArabicIndicDigits(int value) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return value
      .toString()
      .split('')
      .map((digit) => eastern[western.indexOf(digit)])
      .join();
}

TajweedLegendBucket? _bucketForRawClass(String? rawClass) {
  return switch (rawClass) {
    'ikhafa' || 'ikhafa_shafawi' => TajweedLegendBucket.ikhfa,
    'ghunnah' ||
    'idgham_ghunnah' ||
    'idgham_shafawi' =>
      TajweedLegendBucket.idghamWithGhunnah,
    'iqlab' => TajweedLegendBucket.iqlab,
    'idgham_wo_ghunnah' ||
    'idgham_mutajanisayn' ||
    'idgham_mutaqaribayn' =>
      TajweedLegendBucket.idghamWithoutGhunnah,
    'qalaqah' => TajweedLegendBucket.qalqalah,
    _ => null,
  };
}

final RegExp _ruleClassPattern = RegExp(
  r"""class\s*=\s*(?:'([^']+)'|"([^"]+)"|([^\s>]+))""",
);

class _QpcHafsTajweedBundle {
  const _QpcHafsTajweedBundle({
    required this.catalog,
    required this.tajweedBySurah,
  });

  final List<SurahData> catalog;
  final Map<int, Map<int, TajweedAyahData>> tajweedBySurah;
}

class _ParsedWordMarkup {
  const _ParsedWordMarkup({
    required this.markup,
    required this.plainText,
  });

  final String markup;
  final String plainText;
}

class _RuleMarkupRun {
  const _RuleMarkupRun({
    required this.text,
    required this.rawClass,
  });

  final String text;
  final String? rawClass;

  _RuleMarkupRun copyWith({
    String? text,
    String? rawClass,
  }) {
    return _RuleMarkupRun(
      text: text ?? this.text,
      rawClass: rawClass ?? this.rawClass,
    );
  }
}
