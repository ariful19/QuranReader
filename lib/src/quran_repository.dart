import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

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
    this.assetPath = 'Resources/quran-uthmani.xml',
  });

  final String assetPath;

  @override
  Future<List<SurahData>> loadCatalog() async {
    final xmlString = await rootBundle.loadString(assetPath);
    final document = XmlDocument.parse(xmlString);

    final catalog = <SurahData>[];
    for (final suraElement in document.findAllElements('sura')) {
      final index = int.parse(suraElement.getAttribute('index')!);
      final seed = surahSeeds[index];
      if (seed == null) {
        throw StateError('Missing metadata seed for surah $index.');
      }

      final ayahs = suraElement.findElements('aya').map((ayaElement) {
        return AyahData(
          number: int.parse(ayaElement.getAttribute('index')!),
          text: ayaElement.getAttribute('text') ?? '',
          bismillah: ayaElement.getAttribute('bismillah'),
        );
      }).toList(growable: false);

      final totalUnicodeChars = ayahs.fold<int>(
        0,
        (sum, ayah) => sum + ayah.unicodeChars,
      );

      catalog.add(
        SurahData(
          index: index,
          arabicName: suraElement.getAttribute('name') ?? '',
          englishName: seed.englishName,
          chronologicalOrder: seed.chronologicalOrder,
          ayahs: ayahs,
          totalUnicodeChars: totalUnicodeChars,
        ),
      );
    }

    catalog.sort((left, right) => left.index.compareTo(right.index));
    return catalog;
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
    this.assetPath = 'Resources/quran-tajweed.json',
  });

  final String assetPath;

  @override
  Future<Map<int, Map<int, TajweedAyahData>>> loadTajweed() async {
    final jsonString = await rootBundle.loadString(assetPath);
    return parseTajweedSourceJson(jsonString);
  }
}

Map<int, Map<int, TajweedAyahData>> parseTajweedSourceJson(String jsonString) {
  final decoded = jsonDecode(jsonString) as Map<String, Object?>;
  final rawChapters = (decoded['chapters'] as List<Object?>? ?? const [])
      .cast<Map<Object?, Object?>>();

  return {
    for (final rawChapter in rawChapters)
      (rawChapter['surahIndex'] as int): {
        for (final rawAyah
            in (rawChapter['ayahs'] as List<Object?>? ?? const [])
                .cast<Map<Object?, Object?>>())
          (rawAyah['ayahNumber'] as int): TajweedAyahData.fromJson(
            rawAyah.map((key, value) => MapEntry(key as String, value)),
          ),
      },
  };
}

