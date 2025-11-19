// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_buddy/services/auth_service.dart';
import '../config/app_config.dart';
import '../models/room.dart';

class Api {
  /// Base URL for the backend — resolved by AppConfig.init()
  static String get base => AppConfig.apiBase;

  /// Shared HTTP timeout for all backend calls.
  /// Bump this if Cloud Run cold starts still hit the limit.
  static const Duration _timeout = Duration(seconds: 30);

  /// Build a Uri for GET/POST with optional query parameters.
  static Uri _u(String path, [Map<String, String>? qp]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: qp);
  }

  /// Common headers, inject Firebase ID token if available.
  static Future<Map<String, String>> _headers() async {
    final user = AuthService.instance.currentUser;
    String? token;
    if (user != null) {
      token = await user.getIdToken(true);
    }

    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }


  /// Simple one-shot list (non-paginated). Accepts optional filters.
  /// Handles either { "items": [...] } or a bare JSON array.
  static Future<List<Room>> listRooms({
    int limit = 200,
    String? building,
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (building?.isNotEmpty == true) qp['building'] = building!;

    final uri = _u('/rooms/', qp);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to load rooms ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final List<dynamic> list = decoded is Map<String, dynamic>
        ? (decoded['items'] as List<dynamic>)
        : (decoded as List<dynamic>);

    return list
        .cast<Map<String, dynamic>>()
        .map((m) => Room.fromJson(m))
        .toList();
  }

  /// Paginated fetch. Backend should return:
  /// { "items": [...], "nextPageToken": "..." }
  static Future<RoomsPage> listRoomsPage({
    int limit = 50,
    String? pageToken,
    String? building,
    String? startTime,    // "HH:mm"
    String? endTime,      // "HH:mm"
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (pageToken != null) qp['pageToken'] = pageToken;
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (startTime?.isNotEmpty == true) qp['startTime'] = startTime!;
    if (endTime?.isNotEmpty == true) qp['endTime'] = endTime!;

    final uri = _u('/rooms/', qp);
    final resp = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception("Rooms request failed: ${resp.statusCode} ${resp.body}");
    }
    final data = jsonDecode(resp.body);
    return data is List
        ? RoomsPage(items: (data.cast<Map<String,dynamic>>()).map(Room.fromJson).toList(), nextPageToken: null)
        : RoomsPage.fromJson(data as Map<String, dynamic>);
  }


  /// (Optional) Convenience stream to iterate all pages.
  static Stream<Room> listAllRooms({
    int pageSize = 100,
    String? building,
  }) async* {
    String? token;
    do {
      final page = await listRoomsPage(
        limit: pageSize,
        pageToken: token,
        building: building,
      );
      for (final r in page.items) {
        yield r;
      }
      token = page.nextPageToken;
    } while (token != null && token.isNotEmpty);
  }

  /// Increment lockedReports for a room slot and return the new count.
  static Future<int> reportRoomLocked(String roomId) async {
    final uri = _u('/rooms/$roomId/report_locked');
    final resp = await http
        .post(uri, headers: await _headers())
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to report room locked (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final count = data['lockedReports'];
    if (count is int) return count;
    return int.tryParse(count?.toString() ?? '0') ?? 0;
  }
}
