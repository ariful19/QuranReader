import 'package:flutter/foundation.dart';

@immutable
class WordInsightRequest {
  const WordInsightRequest({
    required this.surahIndex,
    required this.surahName,
    required this.ayahNumber,
    required this.ayahText,
    required this.word,
    required this.occurrenceIndex,
  });

  final int surahIndex;
  final String surahName;
  final int ayahNumber;
  final String ayahText;
  final String word;
  final int occurrenceIndex;

  String get normalizedWord => normalizeWordForCache(word);
}

@immutable
class AyahInsightRequest {
  const AyahInsightRequest({
    required this.surahIndex,
    required this.surahName,
    required this.ayahNumber,
    required this.ayahText,
  });

  final int surahIndex;
  final String surahName;
  final int ayahNumber;
  final String ayahText;
}

@immutable
class GroundingSource {
  const GroundingSource({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }

  factory GroundingSource.fromJson(Map<String, Object?> json) {
    return GroundingSource(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

@immutable
class WordInsight {
  const WordInsight({
    required this.word,
    required this.bengaliMeaning,
    required this.contextualMeaning,
    required this.root,
    required this.masdar,
    required this.partOfSpeech,
    required this.linguisticNotes,
    required this.confidenceNote,
  });

  final String word;
  final String bengaliMeaning;
  final String contextualMeaning;
  final String root;
  final String masdar;
  final String partOfSpeech;
  final String linguisticNotes;
  final String confidenceNote;

  Map<String, Object?> toJson() {
    return {
      'word': word,
      'bengaliMeaning': bengaliMeaning,
      'contextualMeaning': contextualMeaning,
      'root': root,
      'masdar': masdar,
      'partOfSpeech': partOfSpeech,
      'linguisticNotes': linguisticNotes,
      'confidenceNote': confidenceNote,
    };
  }

  factory WordInsight.fromJson(Map<String, Object?> json) {
    return WordInsight(
      word: json['word'] as String? ?? '',
      bengaliMeaning: json['bengaliMeaning'] as String? ?? '',
      contextualMeaning: json['contextualMeaning'] as String? ?? '',
      root: json['root'] as String? ?? '',
      masdar: json['masdar'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      linguisticNotes: json['linguisticNotes'] as String? ?? '',
      confidenceNote: json['confidenceNote'] as String? ?? '',
    );
  }
}

@immutable
class AyahInsight {
  const AyahInsight({
    required this.bengaliMeaning,
    required this.tafsirSummary,
    required this.keyThemes,
    required this.practicalLessons,
    required this.sources,
  });

  final String bengaliMeaning;
  final String tafsirSummary;
  final String keyThemes;
  final String practicalLessons;
  final List<GroundingSource> sources;

  Map<String, Object?> toJson() {
    return {
      'bengaliMeaning': bengaliMeaning,
      'tafsirSummary': tafsirSummary,
      'keyThemes': keyThemes,
      'practicalLessons': practicalLessons,
      'sources': sources.map((source) => source.toJson()).toList(),
    };
  }

  factory AyahInsight.fromJson(Map<String, Object?> json) {
    final rawSources = (json['sources'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    return AyahInsight(
      bengaliMeaning: json['bengaliMeaning'] as String? ?? '',
      tafsirSummary: json['tafsirSummary'] as String? ?? '',
      keyThemes: json['keyThemes'] as String? ?? '',
      practicalLessons: json['practicalLessons'] as String? ?? '',
      sources: rawSources
          .map(
            (source) => GroundingSource.fromJson(
              source.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(growable: false),
    );
  }

  AyahInsight copyWith({
    String? bengaliMeaning,
    String? tafsirSummary,
    String? keyThemes,
    String? practicalLessons,
    List<GroundingSource>? sources,
  }) {
    return AyahInsight(
      bengaliMeaning: bengaliMeaning ?? this.bengaliMeaning,
      tafsirSummary: tafsirSummary ?? this.tafsirSummary,
      keyThemes: keyThemes ?? this.keyThemes,
      practicalLessons: practicalLessons ?? this.practicalLessons,
      sources: sources ?? this.sources,
    );
  }
}

@immutable
class WordInsightRecord {
  const WordInsightRecord({
    required this.surahIndex,
    required this.ayahNumber,
    required this.word,
    required this.normalizedWord,
    required this.occurrenceIndex,
    required this.promptVersion,
    required this.model,
    required this.generatedAt,
    required this.insight,
  });

  final int surahIndex;
  final int ayahNumber;
  final String word;
  final String normalizedWord;
  final int occurrenceIndex;
  final int promptVersion;
  final String model;
  final DateTime generatedAt;
  final WordInsight insight;

  Map<String, Object?> toJson() {
    return {
      'surahIndex': surahIndex,
      'ayahNumber': ayahNumber,
      'word': word,
      'normalizedWord': normalizedWord,
      'occurrenceIndex': occurrenceIndex,
      'promptVersion': promptVersion,
      'model': model,
      'generatedAt': generatedAt.toIso8601String(),
      'insight': insight.toJson(),
    };
  }

  factory WordInsightRecord.fromJson(Map<String, Object?> json) {
    return WordInsightRecord(
      surahIndex: json['surahIndex'] as int,
      ayahNumber: json['ayahNumber'] as int,
      word: json['word'] as String? ?? '',
      normalizedWord: json['normalizedWord'] as String? ?? '',
      occurrenceIndex: json['occurrenceIndex'] as int,
      promptVersion: json['promptVersion'] as int,
      model: json['model'] as String? ?? '',
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      insight: WordInsight.fromJson(
        (json['insight'] as Map<Object?, Object?>).map(
          (key, value) => MapEntry(key as String, value),
        ),
      ),
    );
  }
}

@immutable
class AyahInsightRecord {
  const AyahInsightRecord({
    required this.surahIndex,
    required this.ayahNumber,
    required this.promptVersion,
    required this.model,
    required this.generatedAt,
    required this.insight,
  });

  final int surahIndex;
  final int ayahNumber;
  final int promptVersion;
  final String model;
  final DateTime generatedAt;
  final AyahInsight insight;

  Map<String, Object?> toJson() {
    return {
      'surahIndex': surahIndex,
      'ayahNumber': ayahNumber,
      'promptVersion': promptVersion,
      'model': model,
      'generatedAt': generatedAt.toIso8601String(),
      'insight': insight.toJson(),
    };
  }

  factory AyahInsightRecord.fromJson(Map<String, Object?> json) {
    return AyahInsightRecord(
      surahIndex: json['surahIndex'] as int,
      ayahNumber: json['ayahNumber'] as int,
      promptVersion: json['promptVersion'] as int,
      model: json['model'] as String? ?? '',
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      insight: AyahInsight.fromJson(
        (json['insight'] as Map<Object?, Object?>).map(
          (key, value) => MapEntry(key as String, value),
        ),
      ),
    );
  }
}

@immutable
class InsightLoadResult<T> {
  const InsightLoadResult({
    required this.data,
    required this.isFromCache,
  });

  final T data;
  final bool isFromCache;
}

String normalizeWordForCache(String value) {
  final trimmed = value.trim();
  final runes = trimmed.runes.where((rune) => !_isIgnorableWordRune(rune));
  return String.fromCharCodes(runes);
}

bool _isIgnorableWordRune(int rune) {
  return rune == 0x0640 || (rune >= 0x06D6 && rune <= 0x06ED);
}
