import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL of the REST API, set at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
/// The default reaches a server on the development machine from the Android emulator.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');

/// An error answer from the API, in its standard `{ "error": { code, message } }` shape.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}

/// One record in a pull response.
class PulledRecord {
  PulledRecord({required this.table, required this.id, required this.serverSeq, required this.deleted, required this.data, this.createdOnDevice});

  factory PulledRecord.fromJson(Map<String, dynamic> json) => PulledRecord(
        table: json['table'] as String,
        id: json['id'] as String,
        serverSeq: json['serverSeq'] as int,
        deleted: json['deleted'] as bool,
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdOnDevice: json['createdOnDevice'] == null ? null : DateTime.parse(json['createdOnDevice'] as String),
      );

  final String table;
  final String id;
  final int serverSeq;
  final bool deleted;
  final Map<String, dynamic> data;
  final DateTime? createdOnDevice;
}

class PullPage {
  PullPage(this.records, this.nextSince, this.hasMore);

  final List<PulledRecord> records;
  final int nextSince;
  final bool hasMore;
}

/// The `/auth` and `/sync` endpoints (docs/openapi.yaml).
class SyncApi {
  SyncApi({http.Client? client, this._baseUrl = apiBaseUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  /// Signs in and returns the access token (M1 FE-2, Phase 0 skeleton).
  Future<String> login(String username, String password) async {
    final body = await _send('POST', '/auth/login', body: {'username': username, 'password': password});
    return body['accessToken'] as String;
  }

  /// Pushes outbox payloads; returns the server's result for each record.
  Future<List<Map<String, dynamic>>> push(String token, String deviceId, List<Map<String, dynamic>> records) async {
    final body = await _send('POST', '/sync/push', token: token, body: {'deviceId': deviceId, 'records': records});
    return (body['results'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<PullPage> pull(String token, int since, {int limit = 100}) async {
    final body = await _send('GET', '/sync/pull?since=$since&limit=$limit', token: token);
    return PullPage(
      (body['records'] as List).map((r) => PulledRecord.fromJson(Map<String, dynamic>.from(r as Map))).toList(),
      body['nextSince'] as int,
      body['hasMore'] as bool,
    );
  }

  Future<Map<String, dynamic>> _send(String method, String path, {String? token, Object? body}) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    // Always UTF-8: Urdu text would be garbled if a response came without a charset.
    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final error = (decoded['error'] as Map?) ?? const {};
      throw ApiException(response.statusCode, (error['code'] ?? 'HTTP_${response.statusCode}') as String, (error['message'] ?? '') as String);
    }
    return decoded;
  }
}
