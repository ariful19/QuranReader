import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_reader/src/ai_services.dart';
import 'package:quran_reader/src/app_controller.dart';
import 'package:quran_reader/src/models.dart';
import 'package:quran_reader/src/progress_repository.dart';
import 'package:quran_reader/src/progress_sync_service.dart';
import 'package:quran_reader/src/quran_repository.dart';
import 'package:quran_reader/src/settings_page.dart';

void main() {
  test('sync merges remote progress, goal, and last-read position', () async {
    final syncService = _MemoryProgressSyncService();
    syncService.snapshotByKey['shared-key'] = SyncProgressSnapshot(
      syncKey: 'shared-key',
      progressBySurah: const {
        1: SurahProgress(
          ranges: [AyahRange(fromAyah: 1, toAyah: 2)],
          updatedAtEpochMs: 100,
        ),
      },
      goalState: GoalState(
        goalDate: DateTime(2026, 12, 31),
        startDate: DateTime(2026, 5, 1),
      ),
      goalUpdatedAtEpochMs: 100,
      lastReadAyahBySurah: const {1: 2},
      lastReadUpdatedAtBySurah: const {1: 100},
    );

    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiCacheRepository: MemoryAiCacheRepository(),
      progressSyncService: syncService,
    );
    await controller.load();

    await controller.saveRange(
      surah: controller.surahByIndex(2),
      fromAyah: 1,
      toAyah: 1,
    );

    final result = await controller.syncProgress('shared-key');

    expect(result, isNull);
    expect(controller.syncKey, 'shared-key');
    expect(controller.goalState, isNotNull);
    expect(controller.goalState!.goalDate, DateTime(2026, 12, 31));
    expect(controller.rangesFor(1), hasLength(1));
    expect(controller.rangesFor(1).first.fromAyah, 1);
    expect(controller.rangesFor(2), hasLength(1));
    expect(controller.lastReadAyahFor(1), 2);

    final savedSnapshot = syncService.snapshotByKey['shared-key']!;
    expect(savedSnapshot.progressBySurah[1]!.ranges, hasLength(1));
    expect(savedSnapshot.progressBySurah[2]!.ranges, hasLength(1));
    expect(savedSnapshot.goalState, isNotNull);
  });

  test('clearing a goal syncs across devices', () async {
    final syncService = _MemoryProgressSyncService();
    final firstStore = _MemoryStateStore();
    final secondStore = _MemoryStateStore();

    final firstController = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: firstStore,
      aiCacheRepository: MemoryAiCacheRepository(),
      progressSyncService: syncService,
    );
    await firstController.load();
    await firstController.saveGoal(DateTime(2026, 11, 20));
    expect(await firstController.syncProgress('shared-key'), isNull);

    final secondController = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: secondStore,
      aiCacheRepository: MemoryAiCacheRepository(),
      progressSyncService: syncService,
    );
    await secondController.load();
    expect(await secondController.syncProgress('shared-key'), isNull);
    expect(secondController.goalState, isNotNull);

    await secondController.clearGoal();
    expect(await secondController.syncProgress('shared-key'), isNull);

    expect(await firstController.syncProgress('shared-key'), isNull);
    expect(firstController.goalState, isNull);
  });

  testWidgets('settings page syncs using the editable key field',
      (tester) async {
    final syncService = _MemoryProgressSyncService();
    final controller = QuranAppController(
      catalogSource: _SimpleCatalogSource(),
      appStateStore: _MemoryStateStore(),
      aiCacheRepository: MemoryAiCacheRepository(),
      progressSyncService: syncService,
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SettingsPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final syncKeyField = tester.widget<TextField>(
      find.byKey(const Key('sync-key-field')),
    );
    expect(syncKeyField.controller!.text, isNotEmpty);

    await tester.enterText(
      find.byKey(const Key('sync-key-field')),
      'shared-key',
    );
    await tester.tap(find.byKey(const Key('sync-progress-button')));
    await tester.pumpAndSettle();

    expect(controller.syncKey, 'shared-key');
    expect(syncService.snapshotByKey['shared-key'], isNotNull);
    expect(
        find.text('Progress and goal synced with this key.'), findsOneWidget);
  });
}

class _SimpleCatalogSource implements CatalogSource {
  @override
  Future<List<SurahData>> loadCatalog() async {
    return [
      const SurahData(
        index: 1,
        arabicName: 'الفاتحة',
        englishName: 'The Opening',
        chronologicalOrder: 5,
        totalUnicodeChars: 30,
        ayahs: [
          AyahData(number: 1, text: 'اية 1'),
          AyahData(number: 2, text: 'اية 2'),
        ],
      ),
      const SurahData(
        index: 2,
        arabicName: 'البقرة',
        englishName: 'The Cow',
        chronologicalOrder: 87,
        totalUnicodeChars: 30,
        ayahs: [
          AyahData(number: 1, text: 'اية 1'),
          AyahData(number: 2, text: 'اية 2'),
        ],
      ),
    ];
  }
}

class _MemoryStateStore implements AppStateStore {
  PersistedState? _state;

  @override
  Future<void> clear() async {
    _state = null;
  }

  @override
  Future<PersistedState?> load() async => _state;

  @override
  Future<void> save(PersistedState state) async {
    _state = state;
  }
}

class _MemoryProgressSyncService implements ProgressSyncService {
  final Map<String, SyncProgressSnapshot> snapshotByKey = {};

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Future<SyncProgressSnapshot?> fetch(String syncKey) async {
    return snapshotByKey[syncKey];
  }

  @override
  Future<void> save(SyncProgressSnapshot snapshot) async {
    snapshotByKey[snapshot.syncKey] = snapshot;
  }
}
