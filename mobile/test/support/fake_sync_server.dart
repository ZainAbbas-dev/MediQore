import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediqore/auth/pin_reset.dart';

/// JSON response encoded as UTF-8, like the real API (Urdu text included).
http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _error(int status, String code) => _json({
  'error': {'code': code, 'message': code},
}, status);

/// A fake API for tests: activation with the admin's one-time code and its
/// activation secret (M1 FE-2), sign-in again on an activated phone, rotating
/// refresh tokens, and /sync that keeps records in memory and numbers them like
/// the real server (one global sequence).
class FakeSyncServer {
  FakeSyncServer({this.username = 'lhw.demo', this.password = 'demo-password', this.userId = 'user-1'});

  String username;
  String password;
  String userId;
  String fullName = 'Demo LHW';
  String? lhwCode = 'LHW-DEMO-001';
  String areaId = 'area-1';
  String areaName = 'Demo Area 1';

  /// Only LHW accounts may use the app (APP_FOR_LHWS otherwise).
  String role = 'lhw';

  /// Sent at sign-in: the highest patient number used with this LHW code (M2 FE-1).
  int lastPatientNumber = 0;
  bool deactivated = false;
  bool offline = false;

  /// Phones activated for the account.
  final Set<String> activatedDevices = {};

  /// The unused activation code the admin issued, if any.
  String? activationCode;

  /// The secret activation sends to the phone (32 bytes of 7, base64url), the
  /// same as the API's shared test vector.
  static final List<int> activationSecret = List.filled(32, 7);

  /// The area supervisors sent with every session, for the emergency call.
  List<Map<String, String>> supervisors = [
    {'name': 'Syn Supervisor', 'phone': '0000-1112223'},
  ];
  final Set<String> revokedRefreshTokens = {};
  final Set<String> validAccessTokens = {};
  final Set<String> validRefreshTokens = {};
  final List<String> requests = [];

  /// The full address of each request, to check which server the app called.
  final List<Uri> urls = [];

  final Map<String, Map<String, dynamic>> records = {};
  final List<List<Map<String, dynamic>>> pushedBatches = [];
  final Set<String> rejectIds = {};

  /// Records the server holds in its conflict queue instead of storing them,
  /// like a second visit on the same day (M3 FE-2).
  final Set<String> holdIds = {};
  int _seq = 0;
  int _tokens = 0;

  /// Marks [deviceId] activated, as if it had been activated earlier.
  void activate(String deviceId) => activatedDevices.add(deviceId);

  /// Issues an activation code, as an admin would on the portal; an earlier
  /// unused code stops working.
  String issueActivationCode() => activationCode = 'K7QM-4R2X';

  /// The reply code the portal gives a supervisor for [challenge].
  String replyCodeFor(String challenge) => resetReplyFor(activationSecret, challenge);

  /// Makes every access token expire, so the next request gets 401.
  void expireAccessTokens() => validAccessTokens.clear();

  Map<String, dynamic> _session(String? deviceId) {
    final access = 'access-${++_tokens}';
    final refresh = 'refresh-$_tokens-0123456789abcdef';
    validAccessTokens.add(access);
    validRefreshTokens.add(refresh);
    return {
      'status': 'ok',
      'accessToken': access,
      'tokenType': 'Bearer',
      'expiresIn': '15m',
      'refreshToken': refresh,
      'refreshExpiresAt': '2026-11-01T00:00:00.000Z',
      'supervisors': supervisors,
      'user': {
        'id': userId,
        'username': username,
        'role': 'lhw',
        'fullName': fullName,
        'lhwCode': lhwCode,
        'areaId': areaId,
        'areaName': areaName,
        'lastPatientNumber': lastPatientNumber,
      },
    };
  }

  late final MockClient client = MockClient((request) async {
    if (offline) throw http.ClientException('no network');
    final path = request.url.path;
    requests.add('${request.method} ${path.replaceFirst('/api/v1', '')}');
    urls.add(request.url);
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;

    if (path.endsWith('/auth/login') || path.endsWith('/auth/activate')) {
      if ((body['username'] as String).toLowerCase() != username.toLowerCase() || body['password'] != password) {
        return _error(401, 'INVALID_CREDENTIALS');
      }
      if (deactivated) return _error(403, 'ACCOUNT_INACTIVE');
      if (role != 'lhw') return _error(403, 'APP_FOR_LHWS');
      final deviceId = body['deviceId'] as String?;
      if (deviceId == null) return _error(400, 'DEVICE_REQUIRED');
      if (path.endsWith('/auth/activate')) {
        final typed = (body['activationCode'] as String).toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
        final issued = activationCode?.replaceAll('-', '');
        if (issued == null || typed != issued) return _error(400, 'ACTIVATION_CODE_INVALID');
        activationCode = null;
        activatedDevices.add(deviceId);
        return _json({..._session(deviceId), 'activationSecret': base64Url.encode(activationSecret).replaceAll('=', '')}, 200);
      }
      if (!activatedDevices.contains(deviceId)) return _error(403, 'ACTIVATION_REQUIRED');
      return _json(_session(deviceId), 200);
    }
    if (path.endsWith('/auth/refresh')) {
      final token = body['refreshToken'] as String;
      if (!validRefreshTokens.remove(token)) return _error(401, 'INVALID_REFRESH_TOKEN');
      if (deactivated) return _error(403, 'ACCOUNT_INACTIVE');
      return _json(_session(null), 200);
    }
    if (path.endsWith('/auth/logout')) {
      final token = body['refreshToken'] as String;
      validRefreshTokens.remove(token);
      revokedRefreshTokens.add(token);
      return http.Response('', 204);
    }

    final auth = request.headers['Authorization'] ?? '';
    if (!auth.startsWith('Bearer ') || !validAccessTokens.contains(auth.substring(7))) {
      return _error(401, 'UNAUTHORIZED');
    }
    if (deactivated) return _error(403, 'ACCOUNT_INACTIVE');

    if (path.endsWith('/sync/push')) {
      if (!activatedDevices.contains(body['deviceId'])) return _error(403, 'DEVICE_NOT_ALLOWED');
      final batch = (body['records'] as List).cast<Map<String, dynamic>>();
      pushedBatches.add(batch);
      final results = [
        for (final r in batch)
          if (rejectIds.contains(r['id']))
            {'table': r['table'], 'id': r['id'], 'status': 'rejected', 'reason': 'OUT_OF_AREA'}
          else if (holdIds.contains(r['id']))
            {'table': r['table'], 'id': r['id'], 'status': 'conflict', 'conflictId': 'conflict-${r['id']}'}
          else
            _store(r),
      ];
      return _json({'results': results}, 200);
    }
    if (path.endsWith('/sync/pull')) {
      final since = int.parse(request.url.queryParameters['since']!);
      final limit = int.parse(request.url.queryParameters['limit']!);
      final newer = records.values.where((r) => r['areaId'] == areaId && (r['serverSeq'] as int) > since).toList()
        ..sort((a, b) => (a['serverSeq'] as int).compareTo(b['serverSeq'] as int));
      final page = newer.take(limit).map(Map.of).toList();
      return _json({
        'records': page,
        'nextSince': page.isEmpty ? since : page.last['serverSeq'],
        'hasMore': newer.length > limit,
      }, 200);
    }
    return http.Response('', 404);
  });

  Map<String, dynamic> _store(Map<String, dynamic> r) {
    final status = records.containsKey(r['id']) ? 'updated' : 'created';
    records[r['id'] as String] = {
      'table': r['table'],
      'id': r['id'],
      // The area the phone made the record in, as the real server keeps it (M1 FE-3).
      'areaId': r['areaId'] ?? areaId,
      'serverSeq': ++_seq,
      'createdOnDevice': r['createdOnDevice'],
      'deleted': r['deleted'] ?? false,
      'data': r['data'],
    };
    return {'table': r['table'], 'id': r['id'], 'status': status, 'serverSeq': _seq};
  }

  /// A household created by another phone, in the current area unless [inArea] is given.
  void addFromAnotherDevice(String id, String village, {String? inArea}) => addRecord(
        'households',
        id,
        {'householdNumber': null, 'address': null, 'village': village, 'latitude': 33.7, 'longitude': 73.1},
        inArea: inArea,
      );

  /// Any record created by another phone; each call gets the next server number.
  /// A [deleted] record arrives at the next pull as deleted.
  void addRecord(String table, String id, Map<String, dynamic> data, {String? inArea, bool deleted = false}) {
    records[id] = {
      'table': table,
      'id': id,
      'areaId': inArea ?? areaId,
      'serverSeq': ++_seq,
      'createdOnDevice': '2026-10-01T08:00:00.000Z',
      'deleted': deleted,
      'data': data,
    };
  }

  /// A supervisor's decision on a held record (M3 FE-2): the record is stored,
  /// as deleted when it was a duplicate (keep_existing), and the phone gets it
  /// at its next pull.
  void resolveHeld(Map<String, dynamic> pushed, {required bool keep}) {
    holdIds.remove(pushed['id']);
    addRecord(pushed['table'] as String, pushed['id'] as String, pushed['data'] as Map<String, dynamic>, deleted: !keep);
  }
}
