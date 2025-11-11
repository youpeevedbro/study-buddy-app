// lib/services/api.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../models/room.dart';

class Api {
  // Defaults for local dev
  static const String _localHost   = 'http://127.0.0.1:8000';
  static const String _androidEmu  = 'http://10.0.2.2:8000';
  static const String _webDefault  = 'http://localhost:8000';

  /// Base URL for the backend.
  /// Prefers AppConfig.apiBase (from .env), otherwise picks sane defaults per platform.
  static String get base {
    final configured = AppConfig.apiBase;
    if (configured.isNotEmpty) return configured;

    if (kIsWeb) return _webDefault;
    if (Platform.isAndroid) return _androidEmu;
    // iOS simulator, macOS, Windows
    return _localHost;
  }

  /// Build a Uri for GET/POST with optional query parameters.
  static Uri _u(String path, [Map<String, String>? qp]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: qp);
  }

  /// Common headers, inject Firebase ID token if available.
  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /rooms/?limit=...&building=...&date=...
  static Future<List<Room>> listRooms({
    int limit = 200,
    String? building,
    String? date,
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (date?.isNotEmpty == true) qp['date'] = date!;

    final uri = _u('/rooms/', qp);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('Failed to load rooms ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    // Handle either { "items": [...] } or just [ ... ]
    final List<dynamic> list = decoded is Map<String, dynamic>
        ? (decoded['items'] as List<dynamic>)
        : (decoded as List<dynamic>);

    return list
        .cast<Map<String, dynamic>>()
        .map((m) => Room.fromJson(m))
        .toList();
  }
}
