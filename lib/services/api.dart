// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../models/room.dart';

class Api {
  static Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: q);

  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Room>> listRooms({
    int limit = 200,
    String? building,
    String? date,
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (date?.isNotEmpty == true) qp['date'] = date!;

    // Trailing slash avoids 307 redirect noise
    final res = await http.get(_u('/rooms/', qp), headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Failed to load rooms: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((m) => Room.fromJson(m)).toList();
  }
}
