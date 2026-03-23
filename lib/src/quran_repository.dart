import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'models.dart';
import 'surah_metadata.dart';

abstract class CatalogSource {
  Future<List<SurahData>> loadCatalog();
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
