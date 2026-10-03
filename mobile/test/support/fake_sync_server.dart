import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// JSON response encoded as UTF-8, like the real API (Urdu text included).
http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// A fake /sync server that keeps records in memory and numbers them like the
/// real one (one global sequence, a new number on every change).
class FakeSyncServer {
  final Map<String, Map<String, dynamic>> records = {};
  final List<List<Map<String, dynamic>>> pushedBatches = [];
  final Set<String> rejectIds = {};
  int _seq = 0;
  bool offline = false;

  late final MockClient client = MockClient((request) async {
    if (offline) throw http.ClientException('no network');
    if (request.url.path.endsWith('/auth/login')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['username'] == 'lhw.demo' && body['password'] == 'demo-password') {
        return _json({'accessToken': 'token-1', 'tokenType': 'Bearer'}, 200);
      }
      return _json({'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Username or password is incorrect'}}, 401);
    }
    if (request.headers['Authorization'] != 'Bearer token-1') {
      return _json({'error': {'code': 'UNAUTHORIZED', 'message': 'Sign in required'}}, 401);
    }
    if (request.url.path.endsWith('/sync/push')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final batch = (body['records'] as List).cast<Map<String, dynamic>>();
      pushedBatches.add(batch);
      final results = [
        for (final r in batch)
          if (rejectIds.contains(r['id']))
            {'table': r['table'], 'id': r['id'], 'status': 'rejected', 'reason': 'OUT_OF_AREA'}
          else
            _store(r),
      ];
      return _json({'results': results}, 200);
    }
    if (request.url.path.endsWith('/sync/pull')) {
      final since = int.parse(request.url.queryParameters['since']!);
      final limit = int.parse(request.url.queryParameters['limit']!);
      final newer = records.values.where((r) => (r['serverSeq'] as int) > since).toList()
        ..sort((a, b) => (a['serverSeq'] as int).compareTo(b['serverSeq'] as int));
      final page = newer.take(limit).toList();
      return _json({'records': page, 'nextSince': page.isEmpty ? since : page.last['serverSeq'], 'hasMore': newer.length > limit}, 200);
    }
    return http.Response('', 404);
  });

  Map<String, dynamic> _store(Map<String, dynamic> r) {
    final status = records.containsKey(r['id']) ? 'updated' : 'created';
    records[r['id'] as String] = {
      'table': r['table'],
      'id': r['id'],
      'serverSeq': ++_seq,
      'createdOnDevice': r['createdOnDevice'],
      'deleted': r['deleted'] ?? false,
      'data': r['data'],
    };
    return {'table': r['table'], 'id': r['id'], 'status': status, 'serverSeq': _seq};
  }

  /// A record created by another phone in the same area.
  void addFromAnotherDevice(String id, String village) {
    records[id] = {
      'table': 'households',
      'id': id,
      'serverSeq': ++_seq,
      'createdOnDevice': '2026-10-01T08:00:00.000Z',
      'deleted': false,
      'data': {'householdNumber': null, 'address': null, 'village': village, 'latitude': 33.7, 'longitude': 73.1},
    };
  }
}
