import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_buddy/services/auth_service.dart';

const String kApiBase = 'https://studybuddy-backend-157338247439.us-central1.run.app'; // replace with your backend URL

/// GET helper
Future<http.Response> apiGet(String path) async {
  final token = await AuthService.instance.currentUser?.getIdToken();
  final uri = Uri.parse('$kApiBase$path');

  return http.get(
    uri,
    headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );
}

/// POST helper (JSON)
Future<http.Response> apiPost(String path, Map<String, dynamic> body) async {
  final token = await AuthService.instance.currentUser?.getIdToken();
  final uri = Uri.parse('$kApiBase$path');

  return http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
}
