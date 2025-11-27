// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../models/room.dart';
import 'rooms_cache.dart';

class Api {
  /// Base URL for the backend — resolved by AppConfig.init()
  static String get base => AppConfig.apiBase;

  /// Shared HTTP timeout for all backend calls.
  static const Duration _timeout = Duration(seconds: 30);

  /// Build a Uri for GET/POST with optional query parameters.
  static Uri _u(String path, [Map<String, String>? qp]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: qp);
  }

  /// Common headers, inject Firebase ID token if available.
  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken(true);

    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// NON-PAGINATED
  static Future<List<Room>> listRooms({
    int limit = 200,
    String? building,
    String? date,
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (date?.isNotEmpty == true) qp['date'] = date!;

    final uri = _u('/rooms/', qp);
    final res =
    await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception("Failed to load rooms: ${res.statusCode} ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    final List<dynamic> list =
    decoded is Map<String, dynamic> ? decoded['items'] : decoded;

    return list.cast<Map<String, dynamic>>().map(Room.fromJson).toList();
  }

  /// PAGINATED + OPTIONAL LOCAL CACHE
  ///
  /// Backend returns:
  ///   { "items": [...], "nextPageToken": "..." }
  static Future<RoomsPage> listRoomsPage({
    int limit = 50,
    String? pageToken,
    String? building,
    String? startTime, // "HH:mm" (optional)
    String? endTime,   // "HH:mm" (optional)
    String? date,      // "YYYY-MM-DD" (optional)
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (pageToken != null) qp['pageToken'] = pageToken;
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (startTime?.isNotEmpty == true) qp['startTime'] = startTime!;
    if (endTime?.isNotEmpty == true) qp['endTime'] = endTime!;
    if (date?.isNotEmpty == true) qp['date'] = date!;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "anonymous";

    final bool isFirstPage = pageToken == null || pageToken.isEmpty;
    final bool hasTimeFilters =
        (startTime != null && startTime.isNotEmpty) ||
            (endTime != null && endTime.isNotEmpty);

    // ---- Try cache ONLY for first page with no time filters ----
    if (isFirstPage && !hasTimeFilters) {
      final cached = await RoomsCache.load(
        uid: uid,
        limit: limit,
        pageToken: null,
        building: building,
        date: date,
      );

      if (cached != null) {
        try {
          final data = jsonDecode(cached.body);

          if (data is List) {
            return RoomsPage(
              items: data
                  .cast<Map<String, dynamic>>()
                  .map(Room.fromJson)
                  .toList(),
              nextPageToken: null,
            );
          }

          return RoomsPage.fromJson(data as Map<String, dynamic>);
        } catch (_) {
          // If cache is corrupt, just fall through and refetch
        }
      }
    }

    // ---- No cache hit OR we have time filters / later pages → backend call ----
    final uri = _u('/rooms/', qp);
    final resp =
    await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception(
        "Rooms request failed: ${resp.statusCode} ${resp.body}",
      );
    }

    // Save first page without time filters to cache
    if (isFirstPage && !hasTimeFilters) {
      await RoomsCache.save(
        uid: uid,
        limit: limit,
        pageToken: null,
        building: building,
        date: date,
        body: resp.body,
      );
    }

    final data = jsonDecode(resp.body);
    if (data is List) {
      final items =
      data.cast<Map<String, dynamic>>().map(Room.fromJson).toList();
      return RoomsPage(items: items, nextPageToken: null);
    }

    return RoomsPage.fromJson(data as Map<String, dynamic>);
  }

  /// Convenience stream to iterate all pages.
  static Stream<Room> listAllRooms({
    int pageSize = 100,
    String? building,
    String? date,
  }) async* {
    String? token;
    do {
      final page = await listRoomsPage(
        limit: pageSize,
        pageToken: token,
        building: building,
        date: date,
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
    final resp =
    await http.post(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception(
        "Failed to report room locked: ${resp.statusCode} ${resp.body}",
      );
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = json['lockedReports'];
    return raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
  }
}
