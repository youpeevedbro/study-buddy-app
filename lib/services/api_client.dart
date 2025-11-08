// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl; // e.g. "http://127.0.0.1:8000"

  Future<Map<String, dynamic>> getJson(String pathWithSlash) async {
    // IMPORTANT: provide paths WITH trailing slash, e.g. "/rooms/"
    final token = await AuthService.instance.getAccessToken();
    if (token == null) {
      throw Exception('Not logged in (no access token)');
    }

    final uri = Uri.parse('$baseUrl$pathWithSlash'); // ex: http://127.0.0.1:8000/rooms/
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode >= 400) {
      throw Exception('Failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
