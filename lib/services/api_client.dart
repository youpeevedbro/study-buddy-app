import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

const String kApiBase = 'https://YOUR_API_BASE'; // e.g., https://api.studybuddy.dev

Future<http.Response> apiGet(String path) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  final uri = Uri.parse('$kApiBase$path');
  return http.get(uri, headers: {
    if (token != null) 'Authorization': 'Bearer $token',
  });
}
