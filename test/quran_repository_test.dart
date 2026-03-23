import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled Quran catalog from XML', () async {
    final catalog = await const AssetQuranCatalogSource().loadCatalog();

    expect(catalog, hasLength(114));
    expect(catalog.first.arabicName, 'الفاتحة');
    expect(catalog.first.englishName, 'The Opening');
    expect(catalog.first.ayahCount, 7);
    expect(catalog[1].ayahs.first.bismillah, isNotNull);
  });
}
