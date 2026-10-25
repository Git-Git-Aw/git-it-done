import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Keeps track of who is logged in. The token is saved on the device so a page
/// refresh does not log the user out.
class AuthController extends ChangeNotifier {
  AuthController(this._api, this._prefs);

  static const String _tokenKey = 'auth_token';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AppUser? user;

  /// True until the saved login (if any) has been checked with the server.
  bool restoring = true;

  /// A message for the login screen, for example "Your session has expired".
  String? notice;

  Future<void> restore() async {
    final saved = _prefs.getString(_tokenKey);
    if (saved != null) {
      _api.token = saved;
      try {
        final data = await _api.get('/api/auth/me');
        user = AppUser.fromJson(asMap(data['user']));
      } on ApiException {
        await _clear();
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post('/api/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    final token = data['token'] as String;
    _api.token = token;
    await _prefs.setString(_tokenKey, token);
    user = AppUser.fromJson(asMap(data['user']));
    notice = null;
    notifyListeners();
  }

  /// Returns the message from the server.
  Future<String> register({
    required String fullName,
    required String email,
    required String password,
    String? contactNumber,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
    };
    if (contactNumber != null && contactNumber.trim().isNotEmpty) {
      body['contactNumber'] = contactNumber.trim();
    }
    final data = await _api.post('/api/auth/register', body: body);
    return data['message'] as String;
  }

  /// Returns the server response. In development it contains `resetToken`.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final data = await _api.post('/api/auth/forgot-password', body: {'email': email.trim()});
    return asMap(data);
  }

  Future<String> resetPassword(String token, String newPassword) async {
    final data = await _api.post('/api/auth/reset-password', body: {
      'token': token.trim(),
      'newPassword': newPassword,
    });
    return data['message'] as String;
  }

  Future<String> changePassword(String currentPassword, String newPassword) async {
    final data = await _api.post('/api/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    return data['message'] as String;
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } on ApiException {
      // The token is only discarded on this device anyway.
    }
    await _clear();
    notice = null;
    notifyListeners();
  }

  /// Called by the API client when the server says the token is no longer valid.
  void handleUnauthorized() {
    if (user == null) return;
    notice = 'Your session has expired. Please log in again.';
    _api.token = null;
    user = null;
    _prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> _clear() async {
    _api.token = null;
    user = null;
    await _prefs.remove(_tokenKey);
  }
}
