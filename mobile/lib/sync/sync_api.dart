import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/local_account.dart';

/// Base URL of the REST API, set at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
/// The default reaches a server on the development machine from the Android emulator.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');

/// An error answer from the API, in its standard `{ "error": { code, message } }` shape.
/// The server could not be reached: no connection, no answer in time, or a
/// failed secure connection. Records stay on the phone and sync later.
bool isNetworkError(Object error) =>
    error is SocketException || error is http.ClientException || error is TimeoutException || error is HandshakeException;

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
  PulledRecord({
    required this.table,
    required this.id,
    required this.serverSeq,
    required this.deleted,
    required this.data,
    this.areaId,
    this.createdOnDevice,
  });

  factory PulledRecord.fromJson(Map<String, dynamic> json) => PulledRecord(
        table: json['table'] as String,
        id: json['id'] as String,
        areaId: json['areaId'] as String?,
        serverSeq: json['serverSeq'] as int,
        deleted: json['deleted'] as bool,
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdOnDevice: json['createdOnDevice'] == null ? null : DateTime.parse(json['createdOnDevice'] as String),
      );

  final String table;
  final String id;

  /// The area the record is filed under (M1 FE-3).
  final String? areaId;
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

/// Tokens and profile from an activation, sign-in or refresh (M1 FE-2).
class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.supervisors = const [],
    this.activationSecret,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: SessionUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    supervisors: [
      for (final s in (json['supervisors'] as List? ?? const []))
        Supervisor.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    activationSecret: json['activationSecret'] as String?,
  );

  final String accessToken;
  final String refreshToken;
  final SessionUser user;

  /// The supervisors of the LHW's area with a phone number (emergency call).
  final List<Supervisor> supervisors;

  /// Sent once, by activation: the secret that checks PIN-reset reply codes.
  final String? activationSecret;
}

/// The `/auth` and `/sync` endpoints (docs/openapi.yaml).
class SyncApi {
  SyncApi({http.Client? client, this.baseUrl = apiBaseUrl}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The API address, ending in `/api/v1`. Only a test build changes it after
  /// start (AppServices.setServerAddress).
  String baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  /// M1 FE-2: activates this phone with the admin's one-time activation code
  /// and signs in. The answer carries the activation secret, once.
  Future<AuthTokens> activate(String username, String password, {required String code, required String deviceId}) async {
    final body = await _send(
      'POST',
      '/auth/activate',
      body: {'username': username, 'password': password, 'activationCode': code, 'deviceId': deviceId},
    );
    return AuthTokens.fromJson(body);
  }

  /// Signs in again with the password on this activated phone, when its
  /// refresh token no longer works (for example after a password reset).
  Future<AuthTokens> login(String username, String password, {required String deviceId}) async {
    final body = await _send(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password, 'deviceId': deviceId},
    );
    return AuthTokens.fromJson(body);
  }

  /// Swaps a refresh token for a new pair; each refresh token works once.
  Future<AuthTokens> refresh(String refreshToken) async =>
      AuthTokens.fromJson(await _send('POST', '/auth/refresh', body: {'refreshToken': refreshToken}));

  /// Revokes the refresh token (sign-out).
  Future<void> logout(String refreshToken) => _send('POST', '/auth/logout', body: {'refreshToken': refreshToken});

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
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
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
