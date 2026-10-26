import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';

/// An error that is safe to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Talks to the Git-Inside backend. Adds the login token to every request and
/// turns failures into [ApiException]s with a readable message.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Set after login; sent as `Authorization: Bearer <token>`.
  String? token;

  /// Called when the server rejects the token (expired or account disabled).
  void Function()? onUnauthorized;

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

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send(() => _client.get(_uri(path, query), headers: _headers()));
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _send(() => _client.post(
          _uri(path, null),
          headers: _headers(json: true),
          body: jsonEncode(body ?? <String, dynamic>{}),
        ));
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _send(() => _client.put(
          _uri(path, null),
          headers: _headers(json: true),
          body: jsonEncode(body ?? <String, dynamic>{}),
        ));
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _send(() => _client.patch(
          _uri(path, null),
          headers: _headers(json: true),
          body: jsonEncode(body ?? <String, dynamic>{}),
        ));
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
    return _send(() async {
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
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } catch (_) {
      // Browser, Windows and Android report a refused connection with
      // different exception types, so every other failure means "no server".
      throw ApiException(
        'Cannot reach the server at ${AppConfig.apiBaseUrl}. Make sure the backend is running.',
      );
    }

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

    if (response.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }

    String message = 'Request failed (${response.statusCode}).';
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    }
    throw ApiException(message, statusCode: response.statusCode);
  }
}
