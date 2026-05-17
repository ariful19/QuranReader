import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

abstract class ProgressSyncService {
  const ProgressSyncService();

  bool get isAvailable;
  String? get unavailableReason;

  Future<SyncProgressSnapshot?> fetch(String syncKey);
  Future<void> save(SyncProgressSnapshot snapshot);
}

class DisabledProgressSyncService implements ProgressSyncService {
  const DisabledProgressSyncService(this.unavailableReason);

  @override
  final String unavailableReason;

  @override
  bool get isAvailable => false;

  @override
  Future<SyncProgressSnapshot?> fetch(String syncKey) async {
    throw ProgressSyncUnavailableException(unavailableReason);
  }

  @override
  Future<void> save(SyncProgressSnapshot snapshot) async {
    throw ProgressSyncUnavailableException(unavailableReason);
  }
}

class FirebaseProgressSyncService implements ProgressSyncService {
  FirebaseProgressSyncService(FirebaseFirestore firestore)
      : _collection = firestore.collection('QuranReaderProgresses');

  final CollectionReference<Map<String, Object?>> _collection;

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Future<SyncProgressSnapshot?> fetch(String syncKey) async {
    final snapshot = await _collection.doc(syncKey).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return SyncProgressSnapshot.fromJson(syncKey: syncKey, json: data);
  }

  @override
  Future<void> save(SyncProgressSnapshot snapshot) {
    return _collection.doc(snapshot.syncKey).set(snapshot.toJson());
  }
}

class SyncProgressSnapshot {
  const SyncProgressSnapshot({
    required this.syncKey,
    required this.progressBySurah,
    required this.goalState,
    required this.goalUpdatedAtEpochMs,
    required this.lastReadAyahBySurah,
    required this.lastReadUpdatedAtBySurah,
  });

  final String syncKey;
  final Map<int, SurahProgress> progressBySurah;
  final GoalState? goalState;
  final int goalUpdatedAtEpochMs;
  final Map<int, int> lastReadAyahBySurah;
  final Map<int, int> lastReadUpdatedAtBySurah;

  int get updatedAtEpochMs {
    final progressUpdatedAt = progressBySurah.values.fold<int>(
      0,
      (latest, progress) => latest > progress.updatedAtEpochMs
          ? latest
          : progress.updatedAtEpochMs,
    );
    final lastReadUpdatedAt = lastReadUpdatedAtBySurah.values.fold<int>(
      0,
      (latest, updatedAt) => latest > updatedAt ? latest : updatedAt,
    );
    final latestState = goalUpdatedAtEpochMs > progressUpdatedAt
        ? goalUpdatedAtEpochMs
        : progressUpdatedAt;
    return latestState > lastReadUpdatedAt ? latestState : lastReadUpdatedAt;
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'updatedAtEpochMs': updatedAtEpochMs,
      'goalState': goalState?.toJson(),
      'goalUpdatedAtEpochMs': goalUpdatedAtEpochMs,
      'progressBySurah': progressBySurah.map(
        (key, value) => MapEntry('$key', value.toJson()),
      ),
      'lastReadAyahBySurah': lastReadAyahBySurah.map(
        (key, value) => MapEntry('$key', value),
      ),
      'lastReadUpdatedAtBySurah': lastReadUpdatedAtBySurah.map(
        (key, value) => MapEntry('$key', value),
      ),
    };
  }

  factory SyncProgressSnapshot.fromJson({
    required String syncKey,
    required Map<String, Object?> json,
  }) {
    final rawProgress =
        (json['progressBySurah'] as Map<Object?, Object?>?) ?? const {};
    final rawLastReadAyahBySurah =
        (json['lastReadAyahBySurah'] as Map<Object?, Object?>?) ?? const {};
    final rawLastReadUpdatedAtBySurah =
        (json['lastReadUpdatedAtBySurah'] as Map<Object?, Object?>?) ??
            const {};

    return SyncProgressSnapshot(
      syncKey: syncKey,
      progressBySurah: rawProgress.map(
        (key, value) => MapEntry(
          int.parse(key as String),
          SurahProgress.fromJson(
            (value as Map<Object?, Object?>).map(
              (mapKey, mapValue) => MapEntry(mapKey as String, mapValue),
            ),
          ),
        ),
      ),
      goalState: switch (json['goalState']) {
        final Map<Object?, Object?> value => GoalState.fromJson(
            value.map((key, mapValue) => MapEntry(key as String, mapValue)),
          ),
        _ => null,
      },
      goalUpdatedAtEpochMs:
          (json['goalUpdatedAtEpochMs'] as num?)?.toInt() ?? 0,
      lastReadAyahBySurah: rawLastReadAyahBySurah.map(
        (key, value) => MapEntry(
          int.parse(key as String),
          (value as num).toInt(),
        ),
      ),
      lastReadUpdatedAtBySurah: rawLastReadUpdatedAtBySurah.map(
        (key, value) => MapEntry(
          int.parse(key as String),
          (value as num).toInt(),
        ),
      ),
    );
  }
}

Future<ProgressSyncService> createProgressSyncService() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const DisabledProgressSyncService(
      'Sync is available only in the Android app.',
    );
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDVyes4Rgjc8_GTRPwvJilAgMrGGYpr4T8',
          appId: '1:656532861335:android:55d85a608b3f5c1204d4d2',
          messagingSenderId: '656532861335',
          projectId: 'brainsoft-74e85',
          storageBucket: 'brainsoft-74e85.firebasestorage.app',
        ),
      );
    }
    return FirebaseProgressSyncService(FirebaseFirestore.instance);
  } on FirebaseException catch (error) {
    final message = error.message ?? error.code;
    return DisabledProgressSyncService(
      'Sync is unavailable right now: $message',
    );
  }
}

class ProgressSyncUnavailableException implements Exception {
  const ProgressSyncUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
