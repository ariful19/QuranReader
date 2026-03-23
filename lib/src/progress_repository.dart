import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

abstract class AppStateStore {
  Future<PersistedState?> load();
  Future<void> save(PersistedState state);
  Future<void> clear();
}

class SharedPreferencesAppStateStore implements AppStateStore {
  SharedPreferencesAppStateStore(this._preferences);

  static const _storageKey = 'quran_reader.persisted_state.v1';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesAppStateStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAppStateStore(preferences);
  }

  @override
  Future<PersistedState?> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return PersistedState.fromJson(decoded);
  }

  @override
  Future<void> save(PersistedState state) {
    final encoded = jsonEncode(state.toJson());
    return _preferences.setString(_storageKey, encoded);
  }

  @override
  Future<void> clear() {
    return _preferences.remove(_storageKey);
  }
}
