import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/group.dart';

class GroupService {
  const GroupService();

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  Future<http.Response> createGroup(Group group) async {
    final uri = Uri.parse('$baseUrl/groups/create');
    return http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(group.toJson()),
    );
  }
}
