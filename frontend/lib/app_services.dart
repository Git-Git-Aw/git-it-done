import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'data/local_cache.dart';
import 'data/sync_service.dart';
import 'models/models.dart';
import 'state/auth_controller.dart';

/// The few objects shared by the whole app.
class AppServices {
  AppServices._();

  static final ApiClient api = ApiClient();
  static late AuthController auth;

  /// Null when the device cannot save data (the app then works online only).
  static SyncService? sync;

  /// Number of unread notifications, shown as a badge on the Notifications tab.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    CacheStore? cache;
    try {
      cache = await HiveCache.open();
    } catch (_) {
      cache = null;
    }
    api.cache = cache;
    sync = cache == null ? null : SyncService(api, cache);

    auth = AuthController(api, prefs);
    api.onUnauthorized = auth.handleUnauthorized;
    // Forget the badge number when nobody is logged in.
    auth.addListener(() {
      if (auth.user == null) unreadCount.value = 0;
    });
  }

  /// Quietly refreshes the saved copy after login. Errors are ignored.
  static Future<void> backgroundSync(AppUser user) async {
    try {
      await sync?.syncNow(isLandlord: user.isLandlord);
    } catch (_) {
      // Offline: the saved copy simply stays as it is.
    }
  }

  /// Loads the notifications and updates the unread badge.
  static Future<NotificationsResult> loadNotifications() async {
    final data = await api.get('/api/notifications');
    final result = NotificationsResult.fromJson(asMap(data));
    unreadCount.value = result.unread;
    return result;
  }

  /// Updates only the badge. Errors are ignored on purpose (the page that
  /// needs the data shows its own error).
  static Future<void> refreshUnread() async {
    try {
      await loadNotifications();
    } catch (_) {
      // Nothing to do: the badge simply keeps its old number.
    }
  }
}
