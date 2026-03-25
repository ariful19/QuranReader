import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum SurahOrderMode { normal, chronological }

extension SurahOrderModeStorage on SurahOrderMode {
  String get storageValue => name;

  static SurahOrderMode fromStorage(String? value) {
    return SurahOrderMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => SurahOrderMode.normal,
    );
  }
}

@immutable
class SurahSeed {
  const SurahSeed({
    required this.englishName,
    required this.chronologicalOrder,
  });

  final String englishName;
  final int chronologicalOrder;
}

@immutable
class QuranTextRun {
  const QuranTextRun({
    required this.text,
    required this.isAnnotation,
  });

  final String text;
  final bool isAnnotation;
}

enum TajweedLegendBucket {
  ikhfa,
  idghamWithGhunnah,
  iqlab,
  idghamWithoutGhunnah,
  izhar,
  qalqalah,
}

extension TajweedLegendBucketStorage on TajweedLegendBucket {
  String get storageValue => switch (this) {
        TajweedLegendBucket.ikhfa => 'ikhfa',
        TajweedLegendBucket.idghamWithGhunnah => 'idgham_with_ghunnah',
        TajweedLegendBucket.iqlab => 'iqlab',
        TajweedLegendBucket.idghamWithoutGhunnah => 'idgham_without_ghunnah',
        TajweedLegendBucket.izhar => 'izhar',
        TajweedLegendBucket.qalqalah => 'qalqalah',
      };

  static TajweedLegendBucket? fromStorage(String? value) {
    return TajweedLegendBucket.values.cast<TajweedLegendBucket?>().firstWhere(
          (bucket) => bucket?.storageValue == value,
          orElse: () => null,
        );
  }
}

@immutable
class TajweedRun {
  const TajweedRun({
    required this.text,
    this.bucket,
  });

  final String text;
  final TajweedLegendBucket? bucket;

  TajweedRun copyWith({
    String? text,
    TajweedLegendBucket? bucket,
  }) {
    return TajweedRun(
      text: text ?? this.text,
      bucket: bucket ?? this.bucket,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'text': text,
      'bucket': bucket?.storageValue,
    };
  }

  factory TajweedRun.fromJson(Map<String, Object?> json) {
    return TajweedRun(
      text: json['text'] as String? ?? '',
      bucket: TajweedLegendBucketStorage.fromStorage(json['bucket'] as String?),
    );
  }
}

@immutable
class TajweedAyahData {
  const TajweedAyahData({
    required this.ayahNumber,
    required this.plainText,
    required this.runs,
  });

  final int ayahNumber;
  final String plainText;
  final List<TajweedRun> runs;

  Map<String, Object?> toJson() {
    return {
      'ayahNumber': ayahNumber,
      'plainText': plainText,
      'runs': runs.map((run) => run.toJson()).toList(),
    };
  }

  factory TajweedAyahData.fromJson(Map<String, Object?> json) {
    final rawRuns = (json['runs'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    return TajweedAyahData(
      ayahNumber: json['ayahNumber'] as int,
      plainText: json['plainText'] as String? ?? '',
      runs: rawRuns
          .map(
            (run) => TajweedRun.fromJson(
              run.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(growable: false),
    );
  }
}

@immutable
class AyahData {
  const AyahData({
    required this.number,
    required this.text,
    this.bismillah,
  });

  final int number;
  final String text;
  final String? bismillah;

  String get renderedText {
    if (bismillah == null || bismillah!.isEmpty) {
      return text;
    }
    return '${bismillah!} $text';
  }

  List<QuranTextRun> get displayRuns => splitQuranTextRuns(renderedText);

  int get unicodeChars => renderedText.runes.length;
}

@immutable
class SurahData {
  const SurahData({
    required this.index,
    required this.arabicName,
    required this.englishName,
    required this.chronologicalOrder,
    required this.ayahs,
    required this.totalUnicodeChars,
  });

  final int index;
  final String arabicName;
  final String englishName;
  final int chronologicalOrder;
  final List<AyahData> ayahs;
  final int totalUnicodeChars;

  int get ayahCount => ayahs.length;
}

@immutable
class AyahRange {
  const AyahRange({
    required this.fromAyah,
    required this.toAyah,
  }) : assert(fromAyah <= toAyah);

  final int fromAyah;
  final int toAyah;

  bool contains(int ayahNumber) {
    return ayahNumber >= fromAyah && ayahNumber <= toAyah;
  }

  Map<String, Object?> toJson() {
    return {
      'fromAyah': fromAyah,
      'toAyah': toAyah,
    };
  }

  factory AyahRange.fromJson(Map<String, Object?> json) {
    return AyahRange(
      fromAyah: json['fromAyah'] as int,
      toAyah: json['toAyah'] as int,
    );
  }
}

List<AyahRange> mergeAyahRanges(Iterable<AyahRange> ranges) {
  final sorted = [...ranges]
    ..sort((left, right) => left.fromAyah.compareTo(right.fromAyah));
  if (sorted.isEmpty) {
    return const [];
  }

  final merged = <AyahRange>[];
  var current = sorted.first;
  for (final range in sorted.skip(1)) {
    if (range.fromAyah <= current.toAyah + 1) {
      current = AyahRange(
        fromAyah: current.fromAyah,
        toAyah: math.max(current.toAyah, range.toAyah),
      );
      continue;
    }
    merged.add(current);
    current = range;
  }
  merged.add(current);
  return merged;
}

AyahRange suggestedRangeForTappedAyah({
  required Iterable<AyahRange> savedRanges,
  required int tappedAyah,
}) {
  final mergedRanges = mergeAyahRanges(savedRanges);
  AyahRange? containingRange;
  for (final range in mergedRanges) {
    if (range.contains(tappedAyah)) {
      containingRange = range;
      break;
    }
  }

  if (containingRange != null) {
    return AyahRange(fromAyah: tappedAyah, toAyah: tappedAyah);
  }

  AyahRange? previousRange;
  for (final range in mergedRanges) {
    if (range.toAyah < tappedAyah) {
      previousRange = range;
    }
  }

  final fromAyah = previousRange == null ? 1 : previousRange.toAyah + 1;
  return AyahRange(fromAyah: fromAyah, toAyah: tappedAyah);
}

@immutable
class SurahProgress {
  const SurahProgress({this.ranges = const []});

  static const empty = SurahProgress();

  final List<AyahRange> ranges;

  bool get isEmpty => ranges.isEmpty;

  Map<String, Object?> toJson() {
    return {
      'ranges': ranges.map((range) => range.toJson()).toList(),
    };
  }

  factory SurahProgress.fromJson(Map<String, Object?> json) {
    final rawRanges = (json['ranges'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    return SurahProgress(
      ranges: rawRanges
          .map(
            (range) => AyahRange.fromJson(
              range.map(
                (key, value) => MapEntry(key as String, value),
              ),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class LastSavedRangeBookmark {
  const LastSavedRangeBookmark({
    required this.surahIndex,
    required this.fromAyah,
    required this.toAyah,
  });

  final int surahIndex;
  final int fromAyah;
  final int toAyah;

  Map<String, Object?> toJson() {
    return {
      'surahIndex': surahIndex,
      'fromAyah': fromAyah,
      'toAyah': toAyah,
    };
  }

  factory LastSavedRangeBookmark.fromJson(Map<String, Object?> json) {
    return LastSavedRangeBookmark(
      surahIndex: json['surahIndex'] as int,
      fromAyah: json['fromAyah'] as int,
      toAyah: json['toAyah'] as int,
    );
  }
}

@immutable
class GoalState {
  const GoalState({
    required this.goalDate,
    required this.startDate,
  });

  final DateTime goalDate;
  final DateTime startDate;

  Map<String, Object?> toJson() {
    return {
      'goalDate': formatYmd(goalDate),
      'startDate': formatYmd(startDate),
    };
  }

  factory GoalState.fromJson(Map<String, Object?> json) {
    return GoalState(
      goalDate: parseYmd(json['goalDate'] as String),
      startDate: parseYmd(json['startDate'] as String),
    );
  }
}

@immutable
class ReaderSettings {
  const ReaderSettings({
    required this.fontSize,
    required this.backgroundKey,
    required this.tajweedEnabled,
  });

  static const defaultFontSize = 33.0;
  static const minFontSize = 26.0;
  static const maxFontSize = 44.0;
  static const defaultBackgroundKey = 'paper';
  static const defaultTajweedEnabled = false;
  static const defaults = ReaderSettings(
    fontSize: defaultFontSize,
    backgroundKey: defaultBackgroundKey,
    tajweedEnabled: defaultTajweedEnabled,
  );

  final double fontSize;
  final String backgroundKey;
  final bool tajweedEnabled;

  ReaderSettings copyWith({
    double? fontSize,
    String? backgroundKey,
    bool? tajweedEnabled,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      backgroundKey: backgroundKey ?? this.backgroundKey,
      tajweedEnabled: tajweedEnabled ?? this.tajweedEnabled,
    );
  }

  ReaderSettings normalized() {
    return ReaderSettings(
      fontSize: fontSize.clamp(minFontSize, maxFontSize),
      backgroundKey: backgroundKey,
      tajweedEnabled: tajweedEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fontSize': fontSize,
      'backgroundKey': backgroundKey,
      'tajweedEnabled': tajweedEnabled,
    };
  }

  factory ReaderSettings.fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaultFontSize,
      backgroundKey: json['backgroundKey'] as String? ?? defaultBackgroundKey,
      tajweedEnabled: json['tajweedEnabled'] as bool? ?? defaultTajweedEnabled,
    ).normalized();
  }
}

@immutable
class PersistedState {
  const PersistedState({
    required this.orderMode,
    required this.progressBySurah,
    required this.goalState,
    required this.readerSettings,
    required this.lastSavedRangeBookmark,
  });

  final SurahOrderMode orderMode;
  final Map<int, SurahProgress> progressBySurah;
  final GoalState? goalState;
  final ReaderSettings readerSettings;
  final LastSavedRangeBookmark? lastSavedRangeBookmark;

  Map<String, Object?> toJson() {
    return {
      'orderMode': orderMode.storageValue,
      'progressBySurah': progressBySurah.map(
        (key, value) => MapEntry('$key', value.toJson()),
      ),
      'goalState': goalState?.toJson(),
      'readerSettings': readerSettings.toJson(),
      'lastSavedRangeBookmark': lastSavedRangeBookmark?.toJson(),
    };
  }

  factory PersistedState.fromJson(Map<String, Object?> json) {
    final rawProgress = (json['progressBySurah'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    return PersistedState(
      orderMode: SurahOrderModeStorage.fromStorage(
        json['orderMode'] as String?,
      ),
      progressBySurah: rawProgress.map(
        (key, value) => MapEntry(
          int.parse(key),
          SurahProgress.fromJson((value as Map<Object?, Object?>).map(
            (mapKey, mapValue) => MapEntry(mapKey as String, mapValue),
          )),
        ),
      ),
      goalState: switch (json['goalState']) {
        final Map<Object?, Object?> value => GoalState.fromJson(
            value.map((key, mapValue) => MapEntry(key as String, mapValue)),
          ),
        _ => null,
      },
      readerSettings: switch (json['readerSettings']) {
        final Map<Object?, Object?> value => ReaderSettings.fromJson(
            value.map((key, mapValue) => MapEntry(key as String, mapValue)),
          ),
        _ => ReaderSettings.defaults,
      },
      lastSavedRangeBookmark: switch (json['lastSavedRangeBookmark']) {
        final Map<Object?, Object?> value => LastSavedRangeBookmark.fromJson(
            value.map((key, mapValue) => MapEntry(key as String, mapValue)),
          ),
        _ => null,
      },
    );
  }
}

@immutable
class GoalMetrics {
  const GoalMetrics({
    required this.daysRemaining,
    required this.remainingPercent,
    required this.estimatedDays,
    required this.projectedCompletionDate,
    required this.requiredDailyPercent,
  });

  final int daysRemaining;
  final double remainingPercent;
  final int? estimatedDays;
  final DateTime? projectedCompletionDate;
  final double? requiredDailyPercent;
}

DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String formatYmd(DateTime value) {
  final date = dateOnly(value);
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime parseYmd(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  return DateTime(parts[0], parts[1], parts[2]);
}

String formatPercent(double value) {
  return '${value.toStringAsFixed(2)}%';
}

bool isQuranAnnotationRune(int rune) {
  return rune >= 0x06D6 && rune <= 0x06ED;
}

bool isArabicMarkOrAnnotationRune(int rune) {
  return (rune >= 0x064B && rune <= 0x065F) ||
      rune == 0x0670 ||
      isQuranAnnotationRune(rune);
}

bool startsWithArabicMarkOrAnnotation(String text) {
  if (text.isEmpty) {
    return false;
  }
  return isArabicMarkOrAnnotationRune(text.runes.first);
}

List<String> splitArabicTextClusters(String text) {
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

    if (isArabicMarkOrAnnotationRune(rune)) {
      buffer.writeCharCode(rune);
      continue;
    }

    flush();
    buffer.writeCharCode(rune);
  }

  flush();
  return clusters;
}

List<TajweedRun> normalizeTajweedRunsForDisplay(List<TajweedRun> runs) {
  final normalized = <TajweedRun>[];

  void appendRun(TajweedRun run) {
    if (run.text.isEmpty) {
      return;
    }
    if (normalized.isNotEmpty && normalized.last.bucket == run.bucket) {
      final previous = normalized.removeLast();
      normalized.add(
        previous.copyWith(
          text: previous.text + run.text,
        ),
      );
      return;
    }
    normalized.add(run);
  }

  for (final run in runs) {
    var current = run;
    if (startsWithArabicMarkOrAnnotation(current.text) &&
        normalized.isNotEmpty) {
      final previous = normalized.removeLast();
      final previousClusters = splitArabicTextClusters(previous.text);
      if (previousClusters.isNotEmpty) {
        final movedCluster = previousClusters.removeLast();
        final remainingPrevious = previousClusters.join();
        if (remainingPrevious.isNotEmpty) {
          normalized.add(previous.copyWith(text: remainingPrevious));
        }
        current = current.copyWith(text: movedCluster + current.text);
      } else {
        normalized.add(previous);
      }
    }
    appendRun(current);
  }

  return normalized;
}

List<QuranTextRun> splitQuranTextRuns(String text) {
  final runs = <QuranTextRun>[];
  final buffer = StringBuffer();
  bool? currentIsAnnotation;

  void flush() {
    if (buffer.isEmpty || currentIsAnnotation == null) {
      return;
    }
    runs.add(
      QuranTextRun(
        text: buffer.toString(),
        isAnnotation: currentIsAnnotation,
      ),
    );
    buffer.clear();
  }

  for (final rune in text.runes) {
    final isAnnotation = isQuranAnnotationRune(rune);
    if (currentIsAnnotation == null) {
      currentIsAnnotation = isAnnotation;
    } else if (currentIsAnnotation != isAnnotation) {
      flush();
      currentIsAnnotation = isAnnotation;
    }
    buffer.writeCharCode(rune);
  }

  flush();
  return runs;
}
