import '../api/api_client.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'local_cache.dart';

/// What a sync found.
class SyncResult {
  SyncResult({required this.changed});

  /// How many records changed on the server since the last sync.
  final int changed;
}

/// Keeps the copy of the data on this device up to date.
///
/// It asks the server what changed since the last sync (GET /api/sync?since=)
/// and, when something changed (or on the first sync), saves fresh copies of
/// the main lists so those screens also open without a connection.
class SyncService {
  SyncService(this._api, this._cache);

  final ApiClient _api;
  final CacheStore _cache;

  static const List<String> _changeKeys = [
    'payments',
    'maintenance',
    'announcements',
    'notifications',
    'rooms',
    'leases',
    'tenants',
  ];

  String? get _settingKey {
    final scope = _api.cacheScope;
    return scope == null ? null : 'lastSync:$scope';
  }

  /// "Oct 5, 2026 3:07 PM", or "Never".
  String lastSyncText() {
    final key = _settingKey;
    final saved = key == null ? null : _cache.getSetting(key);
    return saved == null ? 'Never' : formatDateTime(saved);
  }

  Future<SyncResult> syncNow({required bool isLandlord}) async {
    final key = _settingKey;
    if (key == null) return SyncResult(changed: 0);
    final since = _cache.getSetting(key);
    final data = asMap(await _api.get(
      '/api/sync',
      query: since == null ? null : {'since': since},
      cached: false,
    ));
    var changed = 0;
    for (final name in _changeKeys) {
      changed += asList(data[name]).length;
    }
    if (since == null || changed > 0) {
      await _prefetch(isLandlord);
    }
    final serverTime = data['serverTime'];
    if (serverTime is String) {
      await _cache.putSetting(key, serverTime);
    }
    return SyncResult(changed: changed);
  }

  Future<void> _prefetch(bool isLandlord) async {
    final period = periodOf(DateTime.now());
    final requests = isLandlord
        ? <MapEntry<String, Map<String, String>?>>[
            MapEntry('/api/dashboard/landlord', {'period': period}),
            const MapEntry('/api/payments', null),
            MapEntry('/api/payments', {'period': period}),
            const MapEntry('/api/rooms', {'archived': 'true'}),
            const MapEntry('/api/tenants', null),
            const MapEntry('/api/maintenance', null),
            const MapEntry('/api/announcements', null),
            const MapEntry('/api/inquiries', null),
            const MapEntry('/api/dorm-info', null),
            const MapEntry('/api/notifications', null),
          ]
        : <MapEntry<String, Map<String, String>?>>[
            const MapEntry('/api/dashboard/tenant', null),
            const MapEntry('/api/payments/mine', null),
            const MapEntry('/api/maintenance/mine', null),
            const MapEntry('/api/announcements', null),
            const MapEntry('/api/notifications', null),
          ];
    for (final request in requests) {
      try {
        await _api.get(request.key, query: request.value);
      } catch (_) {
        // One list failing must not stop the others.
      }
    }
  }
}
