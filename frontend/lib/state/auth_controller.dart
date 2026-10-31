import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Keeps track of who is logged in. The token and the user are saved on the
/// device so a page refresh (or a start without internet) does not log the
/// user out.
class AuthController extends ChangeNotifier {
  AuthController(this._api, this._prefs);

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AppUser? user;

  /// True until the saved login (if any) has been checked with the server.
  bool restoring = true;

  /// A message for the login screen, for example "Your session has expired".
  String? notice;

  void _setUser(AppUser? value) {
    user = value;
    // Saved server answers are kept per account.
    _api.cacheScope = value == null ? null : 'u${value.id}';
  }

  Future<void> _saveUser(AppUser value) async {
    await _prefs.setString(_userKey, jsonEncode(value.toJson()));
  }

  AppUser? _savedUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(asMap(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> restore() async {
    final saved = _prefs.getString(_tokenKey);
    if (saved != null) {
      _api.token = saved;
      try {
        final data = await _api.get('/api/auth/me', cached: false);
        final fresh = AppUser.fromJson(asMap(data['user']));
        _setUser(fresh);
        await _saveUser(fresh);
      } on ApiException catch (e) {
        final offlineUser = _savedUser();
        if (e.statusCode == null && offlineUser != null) {
          // The server cannot be reached: stay logged in and use saved data.
          _setUser(offlineUser);
        } else {
          await _clear();
        }
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
    final loggedIn = AppUser.fromJson(asMap(data['user']));
    _api.token = token;
    await _prefs.setString(_tokenKey, token);
    await _saveUser(loggedIn);
    _setUser(loggedIn);
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
    // Do not leave this person's saved data on a shared computer.
    final scope = _api.cacheScope;
    if (scope != null) {
      try {
        await _api.cache?.clearScope(scope);
      } catch (_) {
        // Nothing more to do if the saved data cannot be removed.
      }
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
    _setUser(null);
    _prefs.remove(_tokenKey);
    _prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> _clear() async {
    _api.token = null;
    _setUser(null);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }
}
