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

  String get cleanedText => stripQuranAnnotations(renderedText);

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
  });

  static const defaultFontSize = 33.0;
  static const minFontSize = 26.0;
  static const maxFontSize = 44.0;
  static const defaultBackgroundKey = 'paper';
  static const defaults = ReaderSettings(
    fontSize: defaultFontSize,
    backgroundKey: defaultBackgroundKey,
  );

  final double fontSize;
  final String backgroundKey;

  ReaderSettings copyWith({
    double? fontSize,
    String? backgroundKey,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      backgroundKey: backgroundKey ?? this.backgroundKey,
    );
  }

  ReaderSettings normalized() {
    return ReaderSettings(
      fontSize: fontSize.clamp(minFontSize, maxFontSize),
      backgroundKey: backgroundKey,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fontSize': fontSize,
      'backgroundKey': backgroundKey,
    };
  }

  factory ReaderSettings.fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaultFontSize,
      backgroundKey: json['backgroundKey'] as String? ?? defaultBackgroundKey,
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
  });

  final SurahOrderMode orderMode;
  final Map<int, SurahProgress> progressBySurah;
  final GoalState? goalState;
  final ReaderSettings readerSettings;

  Map<String, Object?> toJson() {
    return {
      'orderMode': orderMode.storageValue,
      'progressBySurah': progressBySurah.map(
        (key, value) => MapEntry('$key', value.toJson()),
      ),
      'goalState': goalState?.toJson(),
      'readerSettings': readerSettings.toJson(),
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

final RegExp _quranAnnotationSigns = RegExp(r'[\u06D6-\u06ED]');

String stripQuranAnnotations(String text) {
  return text.replaceAll(_quranAnnotationSigns, '');
}
