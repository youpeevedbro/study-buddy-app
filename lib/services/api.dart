// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../config/app_config.dart'; // <-- import AppConfig

class Api {
  static Future<RoomsPage> listRoomsPage({
    int limit = 50,
    String? pageToken,
  }) async {
    // Use dynamic base URL from AppConfig
    final base = AppConfig.baseUrl;

    final qs = Uri(queryParameters: {
      'limit': '$limit',
      if (pageToken != null) 'pageToken': pageToken,
    }).query;

    final url = Uri.parse("$base/rooms/?$qs");
    print("Fetching: $url"); // optional for debugging

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception("Rooms request failed: ${resp.statusCode} ${resp.body}");
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return RoomsPage.fromJson(data);
  }
}
