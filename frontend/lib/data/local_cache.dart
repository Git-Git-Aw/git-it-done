import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// One saved server answer and the time it was saved.
class CachedResponse {
  CachedResponse({required this.data, required this.savedAt});

  final dynamic data;
  final DateTime savedAt;
}

/// Where the app keeps the last answers from the server, so screens still
/// open when the connection is slow or gone.
abstract class CacheStore {
  Future<void> save(String key, dynamic data);

  CachedResponse? read(String key);

  /// Deletes every saved answer that belongs to one account (for example "u3").
  Future<void> clearScope(String scope);

  String? getSetting(String key);

  Future<void> putSetting(String key, String value);
}

/// The real store: a Hive box on the device (IndexedDB on the web).
class HiveCache implements CacheStore {
  HiveCache._(this._box);

  static const String _boxName = 'git_inside_cache';

  final Box<String> _box;

  static Future<HiveCache> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    return HiveCache._(box);
  }

  @override
  Future<void> save(String key, dynamic data) {
    final saved = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
    return _box.put(key, saved);
  }

  @override
  CachedResponse? read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CachedResponse(
        data: map['data'],
        savedAt: DateTime.parse(map['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearScope(String scope) async {
    final prefix = '$scope|';
    final doomed = _box.keys.where((k) => k is String && k.startsWith(prefix)).toList();
    await _box.deleteAll(doomed);
  }

  @override
  String? getSetting(String key) => _box.get('setting:$key');

  @override
  Future<void> putSetting(String key, String value) => _box.put('setting:$key', value);
}

/// A store that lives only in memory. Used by the unit tests.
class MemoryCache implements CacheStore {
  final Map<String, String> _data = {};

  @override
  Future<void> save(String key, dynamic data) async {
    _data[key] = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  @override
  CachedResponse? read(String key) {
    final raw = _data[key];
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return CachedResponse(
      data: map['data'],
      savedAt: DateTime.parse(map['savedAt'] as String),
    );
  }

  @override
  Future<void> clearScope(String scope) async {
    _data.removeWhere((key, _) => key.startsWith('$scope|'));
  }

  @override
  String? getSetting(String key) => _data['setting:$key'];

  @override
  Future<void> putSetting(String key, String value) async {
    _data['setting:$key'] = value;
  }
}
