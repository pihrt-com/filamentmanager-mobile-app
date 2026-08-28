import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum FilamentServerErrorKind {
  invalidAddress,
  authenticationRequired,
  invalidResponse,
}

class FilamentServerException implements Exception {
  const FilamentServerException(this.message, {this.statusCode, this.kind});

  final String message;
  final int? statusCode;
  final FilamentServerErrorKind? kind;

  @override
  String toString() => message;
}

class FilamentServerApi {
  FilamentServerApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String normalizeBaseUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    final uri = Uri.tryParse(result);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const FilamentServerException(
        'Invalid server address.',
        kind: FilamentServerErrorKind.invalidAddress,
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> serverInfo(String baseUrl) =>
      _request('GET', baseUrl, '/api/v1/server-info');

  Future<Map<String, dynamic>> login(
    String baseUrl, {
    required String username,
    required String password,
    required String appVersion,
    required String deviceId,
  }) => _request(
    'POST',
    baseUrl,
    '/api/v1/auth/login',
    body: {
      'username': username,
      'password': password,
      'deviceName': 'FilamentManager Android',
      'appVersion': appVersion,
      'deviceId': deviceId,
    },
  );

  Future<Map<String, dynamic>> refresh(String baseUrl, String refreshToken) =>
      _request(
        'POST',
        baseUrl,
        '/api/v1/auth/refresh',
        body: {'refreshToken': refreshToken},
      );

  Future<Map<String, dynamic>> snapshot(String baseUrl, String accessToken) =>
      _request('GET', baseUrl, '/api/v1/snapshot', accessToken: accessToken);

  Future<Map<String, dynamic>> changes(
    String baseUrl,
    String accessToken,
    int cursor,
  ) => _request(
    'GET',
    baseUrl,
    '/api/v1/sync/changes?after=$cursor&limit=500',
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> push(
    String baseUrl,
    String accessToken,
    List<Map<String, dynamic>> mutations,
  ) => _request(
    'POST',
    baseUrl,
    '/api/v1/sync/push',
    accessToken: accessToken,
    body: {'mutations': mutations},
  );

  Future<void> logout(String baseUrl, String refreshToken) async {
    await _request(
      'POST',
      baseUrl,
      '/api/v1/auth/logout',
      body: {'refreshToken': refreshToken},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String baseUrl,
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${normalizeBaseUrl(baseUrl)}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    late final http.Response response;
    try {
      response = method == 'GET'
          ? await _client
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 20))
          : await _client
                .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
                .timeout(const Duration(seconds: 20));
      debugPrint(
        'FilamentServerApi: HTTP $method ${uri.path} -> ${response.statusCode}',
      );
    } on Object catch (error, stackTrace) {
      debugPrint(
        'FilamentServerApi: HTTP $method ${uri.path} failed: '
        '${error.runtimeType}',
      );
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace, silent: true),
      );
      rethrow;
    }
    Map<String, dynamic> decoded = const {};
    if (response.bodyBytes.isNotEmpty) {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) decoded = value;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FilamentServerException(
        decoded['message']?.toString() ??
            'Server returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
