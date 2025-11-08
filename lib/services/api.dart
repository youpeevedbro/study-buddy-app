// lib/services/api.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/room.dart';
import 'auth_service.dart'; // ⬅️ add this

class Api {
  static const String _localHost  = 'http://127.0.0.1:8000'; // iOS sim / desktop
  static const String _androidEmu = 'http://10.0.2.2:8000';  // Android emulator

  static String get base {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isIOS) return _localHost;
    if (Platform.isAndroid) return _androidEmu;
    return _localHost;
  }

  static Future<List<Room>> listRooms({
    int limit = 200,
    String? building,
    String? start, // "HH:mm"
    String? end,   // "HH:mm"
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (start?.isNotEmpty == true) qp['start'] = start!;
    if (end?.isNotEmpty == true) qp['end'] = end!;

    // NOTE: trailing slash avoids a 307 that can drop headers
    final uri = Uri.parse('$base/rooms/').replace(queryParameters: qp);

    final token = await AuthService.instance.getAccessToken();
    if (token == null) throw Exception('Not logged in (no access token).');

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load rooms: ${res.statusCode} ${res.body}');
    }

    final data  = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((m) => Room.fromJson(m)).toList();
  }
}
