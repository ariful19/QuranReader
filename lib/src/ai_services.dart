import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'ai_models.dart';

abstract class AiSecretsStore {
  Future<String?> loadApiKey();
  Future<void> saveApiKey(String apiKey);
  Future<void> deleteApiKey();
}

class FlutterSecureAiSecretsStore implements AiSecretsStore {
  FlutterSecureAiSecretsStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  static const _apiKeyKey = 'gemini_api_key_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> deleteApiKey() {
    return _storage.delete(key: _apiKeyKey);
  }

  @override
  Future<String?> loadApiKey() async {
    final value = await _storage.read(key: _apiKeyKey);
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  Future<void> saveApiKey(String apiKey) {
    return _storage.write(key: _apiKeyKey, value: apiKey.trim());
  }
}

class MemoryAiSecretsStore implements AiSecretsStore {
  String? _apiKey;

  @override
  Future<void> deleteApiKey() async {
    _apiKey = null;
  }

  @override
  Future<String?> loadApiKey() async => _apiKey;

  @override
  Future<void> saveApiKey(String apiKey) async {
    _apiKey = apiKey.trim();
  }
}

abstract class AiCacheRepository {
  Future<WordInsightRecord?> getWordInsight({
    required int surahIndex,
    required int ayahNumber,
    required String normalizedWord,
    required int occurrenceIndex,
    required int promptVersion,
  });

  Future<void> saveWordInsight(WordInsightRecord record);

  Future<AyahInsightRecord?> getAyahInsight({
    required int surahIndex,
    required int ayahNumber,
    required int promptVersion,
  });

  Future<void> saveAyahInsight(AyahInsightRecord record);

  Future<void> clear();

  Future<void> close();
}

class SqfliteAiCacheRepository implements AiCacheRepository {
  SqfliteAiCacheRepository._(this._database);

  static const _databaseName = 'quran_reader_ai_cache_v1.db';
  static const _wordTable = 'word_insights';
  static const _ayahTable = 'ayah_insights';

  final Database _database;

  static Future<SqfliteAiCacheRepository> open() async {
    final databasePath = await getDatabasesPath();
    final fullPath = path.join(databasePath, _databaseName);
    final database = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_wordTable (
            surah_index INTEGER NOT NULL,
            ayah_number INTEGER NOT NULL,
            normalized_word TEXT NOT NULL,
            occurrence_index INTEGER NOT NULL,
            prompt_version INTEGER NOT NULL,
            payload TEXT NOT NULL,
            PRIMARY KEY (
              surah_index,
              ayah_number,
              normalized_word,
              occurrence_index,
              prompt_version
            )
          )
        ''');
        await db.execute('''
          CREATE TABLE $_ayahTable (
            surah_index INTEGER NOT NULL,
            ayah_number INTEGER NOT NULL,
            prompt_version INTEGER NOT NULL,
            payload TEXT NOT NULL,
            PRIMARY KEY (
              surah_index,
              ayah_number,
              prompt_version
            )
          )
        ''');
      },
    );
    return SqfliteAiCacheRepository._(database);
  }

  @override
  Future<void> clear() async {
    await _database.delete(_wordTable);
    await _database.delete(_ayahTable);
  }

  @override
  Future<void> close() {
    return _database.close();
  }

  @override
  Future<AyahInsightRecord?> getAyahInsight({
    required int surahIndex,
    required int ayahNumber,
    required int promptVersion,
  }) async {
    final rows = await _database.query(
      _ayahTable,
      columns: const ['payload'],
      where:
          'surah_index = ? AND ayah_number = ? AND prompt_version = ?',
      whereArgs: [surahIndex, ayahNumber, promptVersion],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final payload = rows.first['payload'] as String;
    return AyahInsightRecord.fromJson(
      jsonDecode(payload) as Map<String, Object?>,
    );
  }

  @override
  Future<WordInsightRecord?> getWordInsight({
    required int surahIndex,
    required int ayahNumber,
    required String normalizedWord,
    required int occurrenceIndex,
    required int promptVersion,
  }) async {
    final rows = await _database.query(
      _wordTable,
      columns: const ['payload'],
      where: '''
        surah_index = ? AND
        ayah_number = ? AND
        normalized_word = ? AND
        occurrence_index = ? AND
        prompt_version = ?
      ''',
      whereArgs: [
        surahIndex,
        ayahNumber,
        normalizedWord,
        occurrenceIndex,
        promptVersion,
      ],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final payload = rows.first['payload'] as String;
    return WordInsightRecord.fromJson(
      jsonDecode(payload) as Map<String, Object?>,
    );
  }

  @override
  Future<void> saveAyahInsight(AyahInsightRecord record) {
    return _database.insert(
      _ayahTable,
      {
        'surah_index': record.surahIndex,
        'ayah_number': record.ayahNumber,
        'prompt_version': record.promptVersion,
        'payload': jsonEncode(record.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveWordInsight(WordInsightRecord record) {
    return _database.insert(
      _wordTable,
      {
        'surah_index': record.surahIndex,
        'ayah_number': record.ayahNumber,
        'normalized_word': record.normalizedWord,
        'occurrence_index': record.occurrenceIndex,
        'prompt_version': record.promptVersion,
        'payload': jsonEncode(record.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class MemoryAiCacheRepository implements AiCacheRepository {
  final Map<String, WordInsightRecord> _wordRecords =
      <String, WordInsightRecord>{};
  final Map<String, AyahInsightRecord> _ayahRecords =
      <String, AyahInsightRecord>{};

  @override
  Future<void> clear() async {
    _wordRecords.clear();
    _ayahRecords.clear();
  }

  @override
  Future<void> close() async {}

  @override
  Future<AyahInsightRecord?> getAyahInsight({
    required int surahIndex,
    required int ayahNumber,
    required int promptVersion,
  }) async {
    return _ayahRecords[_ayahKey(surahIndex, ayahNumber, promptVersion)];
  }

  @override
  Future<WordInsightRecord?> getWordInsight({
    required int surahIndex,
    required int ayahNumber,
    required String normalizedWord,
    required int occurrenceIndex,
    required int promptVersion,
  }) async {
    return _wordRecords[
      _wordKey(
        surahIndex,
        ayahNumber,
        normalizedWord,
        occurrenceIndex,
        promptVersion,
      )
    ];
  }

  @override
  Future<void> saveAyahInsight(AyahInsightRecord record) async {
    _ayahRecords[
      _ayahKey(record.surahIndex, record.ayahNumber, record.promptVersion)
    ] = record;
  }

  @override
  Future<void> saveWordInsight(WordInsightRecord record) async {
    _wordRecords[
      _wordKey(
        record.surahIndex,
        record.ayahNumber,
        record.normalizedWord,
        record.occurrenceIndex,
        record.promptVersion,
      )
    ] = record;
  }

  String _ayahKey(int surahIndex, int ayahNumber, int promptVersion) {
    return '$surahIndex|$ayahNumber|$promptVersion';
  }

  String _wordKey(
    int surahIndex,
    int ayahNumber,
    String normalizedWord,
    int occurrenceIndex,
    int promptVersion,
  ) {
    return '$surahIndex|$ayahNumber|$normalizedWord|$occurrenceIndex|$promptVersion';
  }
}

class GeminiClient {
  GeminiClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const wordModelName = 'gemini-3-flash-preview';
  static const ayahModelName = 'gemini-3-flash-preview';
  static const wordInsightPromptVersion = 1;
  static const ayahInsightPromptVersion = 3;

  final http.Client _httpClient;

  void close() {
    _httpClient.close();
  }

  Future<AyahInsightRecord> generateAyahInsight({
    required String apiKey,
    required AyahInsightRequest request,
  }) async {
    final response = await _postGenerateContent(
      apiKey: apiKey,
      model: ayahModelName,
      payload: {
        'contents': [
          {
            'parts': [
              {
                'text': _ayahPrompt(request),
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.3,
          'responseMimeType': 'application/json',
          'responseSchema': _ayahInsightSchema,
        },
      },
    );
    final parsed = _parseJsonText(response);
    final sources = _extractSources(response);
    final insight = AyahInsight.fromJson(parsed).copyWith(sources: sources);
    return AyahInsightRecord(
      surahIndex: request.surahIndex,
      ayahNumber: request.ayahNumber,
      promptVersion: ayahInsightPromptVersion,
      model: ayahModelName,
      generatedAt: DateTime.now(),
      insight: insight,
    );
  }

  Future<WordInsightRecord> generateWordInsight({
    required String apiKey,
    required WordInsightRequest request,
  }) async {
    final response = await _postGenerateContent(
      apiKey: apiKey,
      model: wordModelName,
      payload: {
        'contents': [
          {
            'parts': [
              {
                'text': _wordPrompt(request),
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
          'responseSchema': _wordInsightSchema,
        },
      },
    );
    final parsed = _parseJsonText(response);
    return WordInsightRecord(
      surahIndex: request.surahIndex,
      ayahNumber: request.ayahNumber,
      word: request.word,
      normalizedWord: request.normalizedWord,
      occurrenceIndex: request.occurrenceIndex,
      promptVersion: wordInsightPromptVersion,
      model: wordModelName,
      generatedAt: DateTime.now(),
      insight: WordInsight.fromJson(parsed),
    );
  }

  Future<Map<String, Object?>> _postGenerateContent({
    required String apiKey,
    required String model,
    required Map<String, Object?> payload,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode >= 400) {
      final error =
          decoded['error'] as Map<Object?, Object?>? ?? const <Object?, Object?>{};
      final message = error['message'] as String? ??
          'Gemini request failed (${response.statusCode}).';
      throw GeminiException(message);
    }
    return decoded;
  }

  Map<String, Object?> _parseJsonText(Map<String, Object?> response) {
    final candidates =
        (response['candidates'] as List<Object?>? ?? const <Object?>[])
            .cast<Map<Object?, Object?>>();
    if (candidates.isEmpty) {
      throw const GeminiException('Gemini returned no candidates.');
    }
    final content = candidates.first['content'] as Map<Object?, Object?>?;
    final parts =
        (content?['parts'] as List<Object?>? ?? const <Object?>[])
            .cast<Map<Object?, Object?>>();
    final buffer = StringBuffer();
    for (final part in parts) {
      final text = part['text'] as String?;
      if (text != null && text.isNotEmpty) {
        buffer.write(text);
      }
    }
    final rawText = buffer.toString().trim();
    if (rawText.isEmpty) {
      throw const GeminiException('Gemini returned an empty response.');
    }
    final decoded = jsonDecode(rawText);
    if (decoded is! Map<String, Object?>) {
      throw const GeminiException('Gemini returned invalid JSON.');
    }
    return decoded;
  }

  List<GroundingSource> _extractSources(Map<String, Object?> response) {
    final candidates =
        (response['candidates'] as List<Object?>? ?? const <Object?>[])
            .cast<Map<Object?, Object?>>();
    if (candidates.isEmpty) {
      return const [];
    }
    final groundingMetadata =
        candidates.first['groundingMetadata'] as Map<Object?, Object?>?;
    final chunks =
        (groundingMetadata?['groundingChunks'] as List<Object?>? ??
                const <Object?>[])
            .cast<Map<Object?, Object?>>();
    final seenUrls = <String>{};
    final sources = <GroundingSource>[];
    for (final chunk in chunks) {
      final web = chunk['web'] as Map<Object?, Object?>?;
      final url = web?['uri'] as String?;
      final title = web?['title'] as String?;
      if (url == null || url.isEmpty || title == null || title.isEmpty) {
        continue;
      }
      if (!seenUrls.add(url)) {
        continue;
      }
      sources.add(GroundingSource(title: title, url: url));
    }
    return sources;
  }

  String _ayahPrompt(AyahInsightRequest request) {
    return '''
You are helping a Bengali-speaking Quran reader.

Return valid JSON only, matching the provided schema. All field values must be in Bengali except Arabic quotations.
Prioritize classical tafsir and mainstream Islamic references.
Do not fabricate historical claims. If a detail is uncertain, say so briefly in Bengali.
Keep the answer concise and reader-friendly.

Reference: Surah ${request.surahIndex} (${request.surahName}), Ayah ${request.ayahNumber}
Arabic ayah:
${request.ayahText}
''';
  }

  String _wordPrompt(WordInsightRequest request) {
    return '''
You are helping a Bengali-speaking Quran reader understand one Arabic Quran word in context.

Return valid JSON only, matching the provided schema. All field values must be in Bengali except Arabic words/roots/masdar.
Do not guess when uncertain. If a root or masdar is uncertain, say that briefly in Bengali.
Keep each field concise but useful.

Reference: Surah ${request.surahIndex} (${request.surahName}), Ayah ${request.ayahNumber}
Selected word occurrence: ${request.occurrenceIndex}
Selected Arabic word:
${request.word}

Full Arabic ayah for context:
${request.ayahText}
''';
  }
}

class GeminiException implements Exception {
  const GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

const Map<String, Object?> _wordInsightSchema = {
  'type': 'OBJECT',
  'properties': {
    'word': _stringSchema,
    'bengaliMeaning': _stringSchema,
    'contextualMeaning': _stringSchema,
    'root': _stringSchema,
    'masdar': _stringSchema,
    'partOfSpeech': _stringSchema,
    'linguisticNotes': _stringSchema,
    'confidenceNote': _stringSchema,
  },
  'required': [
    'word',
    'bengaliMeaning',
    'contextualMeaning',
    'root',
    'masdar',
    'partOfSpeech',
    'linguisticNotes',
    'confidenceNote',
  ],
};

const Map<String, Object?> _ayahInsightSchema = {
  'type': 'OBJECT',
  'properties': {
    'bengaliMeaning': _stringSchema,
    'tafsirSummary': _stringSchema,
    'keyThemes': _stringSchema,
    'practicalLessons': _stringSchema,
  },
  'required': [
    'bengaliMeaning',
    'tafsirSummary',
    'keyThemes',
    'practicalLessons',
  ],
};

const Map<String, Object?> _stringSchema = {
  'type': 'STRING',
};
