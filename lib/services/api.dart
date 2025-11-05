// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';

class Api {
  // Android emulator -> host machine:
  static const String _base = "http://10.0.2.2:8000";

  static Future<RoomsPage> listRoomsPage({int limit = 50, String? pageToken}) async {
    final qs = Uri(queryParameters: {
      'limit': '$limit',
      if (pageToken != null) 'pageToken': pageToken,
    }).query;

    final url = Uri.parse("$_base/rooms/?$qs");
    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception("Rooms request failed: ${resp.statusCode} ${resp.body}");
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return RoomsPage.fromJson(data);
  }
}
