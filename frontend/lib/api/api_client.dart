import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';
import '../data/local_cache.dart';

/// An error that is safe to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;

  /// Null when the server could not be reached at all.
  final int? statusCode;

  @override
  String toString() => message;
}

/// Talks to the Git-Inside backend. Adds the login token to every request and
/// turns failures into [ApiException]s with a readable message.
///
/// Every successful GET is also saved on the device. When the server cannot be
/// reached, the saved copy is returned and [offlineSince] tells the screens.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Set after login; sent as `Authorization: Bearer <token>`.
  String? token;

  /// Called when the server rejects the token (expired or account disabled).
  void Function()? onUnauthorized;

  /// Where saved answers go. Null means nothing is saved.
  CacheStore? cache;

  /// Keeps each account's saved answers apart, for example "u3".
  /// Null while nobody is logged in (nothing is saved or shown from the cache).
  String? cacheScope;

  /// Set to the time the data was saved while saved data is shown because the
  /// server cannot be reached. Back to null after the next answer from the server.
  final ValueNotifier<DateTime?> offlineSince = ValueNotifier<DateTime?>(null);

  Uri _uri(String path, Map<String, String>? query) {
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String? _cacheKey(String path, Map<String, String>? query) {
    final scope = cacheScope;
    if (cache == null || scope == null) return null;
    final parts = (query ?? <String, String>{})
        .entries
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    return '$scope|$path?${parts.join('&')}';
  }

  /// Set [cached] to false for requests that must never use saved data.
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool cached = true,
  }) async {
    final key = cached ? _cacheKey(path, query) : null;
    try {
      final data = await _send(() => _client.get(_uri(path, query), headers: _headers()));
      if (key != null && data != null) {
        try {
          await cache?.save(key, data);
        } catch (_) {
          // Saving is optional; the screen still gets its data.
        }
      }
      return data;
    } on ApiException catch (e) {
      if (e.statusCode == null && key != null) {
        final saved = cache?.read(key);
        if (saved != null) {
          offlineSince.value = saved.savedAt;
          return saved.data;
        }
      }
      rethrow;
    }
  }

  /// GET that returns the raw text (for the CSV report). Never uses saved data.
  Future<String> getText(String path, {Map<String, String>? query}) async {
    final response = await _perform(
      () => _client.get(_uri(path, query), headers: {
        ..._headers(),
        'Accept': 'text/csv, application/json',
      }),
      write: false,
    );
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode >= 200 && response.statusCode < 300) return text;
    dynamic data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      data = null;
    }
    throw ApiException(_messageFrom(data, response.statusCode), statusCode: response.statusCode);
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _send(
      () => _client.post(
        _uri(path, null),
        headers: _headers(json: true),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      write: true,
    );
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _send(
      () => _client.put(
        _uri(path, null),
        headers: _headers(json: true),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      write: true,
    );
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _send(
      () => _client.patch(
        _uri(path, null),
        headers: _headers(json: true),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      write: true,
    );
  }

  /// Sends a form with one file (for example a receipt or a repair photo).
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const <String, String>{},
    required String fileField,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    return _send(
      () async {
        final request = http.MultipartRequest('POST', _uri(path, null));
        request.headers.addAll(_headers());
        request.fields.addAll(fields);
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ));
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      },
      write: true,
    );
  }

  /// Runs the request. Only network problems are turned into exceptions here.
  Future<http.Response> _perform(
    Future<http.Response> Function() request, {
    required bool write,
  }) async {
    http.Response response;
    try {
      response = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException(
        write
            ? 'The server took too long to respond. Your change may not have been saved. Please check and try again.'
            : 'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      // Browser, Windows and Android report a refused connection with
      // different exception types, so every other failure means "no server".
      throw ApiException(
        write
            ? 'No connection to the server. Your change was NOT saved. Please try again when you are online.'
            : 'Cannot reach the server at ${AppConfig.apiBaseUrl}. Make sure the backend is running.',
      );
    }
    // Any answer, even an error, proves the server can be reached.
    if (offlineSince.value != null) offlineSince.value = null;
    if (response.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }
    return response;
  }

  String _messageFrom(dynamic data, int statusCode) {
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Request failed ($statusCode).';
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    bool write = false,
  }) async {
    final response = await _perform(request, write: write);

    dynamic data;
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } on FormatException {
        data = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(_messageFrom(data, response.statusCode), statusCode: response.statusCode);
  }
}
