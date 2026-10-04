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

/// Tokens from a successful sign-in, code check or refresh (M1 FE-2).
class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken, required this.user});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: SessionUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  );

  final String accessToken;
  final String refreshToken;
  final SessionUser user;
}

/// The answer to a sign-in: tokens, or "this phone needs its one-time code".
class LoginOutcome {
  LoginOutcome.signedIn(AuthTokens this.tokens) : otpRequired = false;
  LoginOutcome.needsCode() : tokens = null, otpRequired = true;

  final AuthTokens? tokens;
  final bool otpRequired;
}

/// The `/auth` and `/sync` endpoints (docs/openapi.yaml).
class SyncApi {
  SyncApi({http.Client? client, this._baseUrl = apiBaseUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  /// M1 FE-2: signs in from this phone. A phone that has not been approved
  /// gets [LoginOutcome.needsCode] (HTTP 202) until [verifyOtp] succeeds.
  Future<LoginOutcome> login(String username, String password, {required String deviceId}) async {
    final (status, body) = await _sendWithStatus(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password, 'deviceId': deviceId},
    );
    if (status == 202 || body['status'] == 'otp_required') return LoginOutcome.needsCode();
    return LoginOutcome.signedIn(AuthTokens.fromJson(body));
  }

  /// Approves this phone with the one-time code an admin or supervisor issued
  /// for it (decision 0002), and signs in.
  Future<AuthTokens> verifyOtp(String username, String password, {required String deviceId, required String code}) async {
    final body = await _send(
      'POST',
      '/auth/otp/verify',
      body: {'username': username, 'password': password, 'deviceId': deviceId, 'code': code},
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

  Future<Map<String, dynamic>> _send(String method, String path, {String? token, Object? body}) async =>
      (await _sendWithStatus(method, path, token: token, body: body)).$2;

  Future<(int, Map<String, dynamic>)> _sendWithStatus(String method, String path, {String? token, Object? body}) async {
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
    return (response.statusCode, decoded);
  }
}
