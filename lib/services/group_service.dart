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

  Future<List<JoinedGroup>> listMyStudyGroups() async {
    final uri = Uri.parse("$baseUrl/group/myStudyGroups");
    final resp = await http.get(uri);
    
    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to retrieve myStudyGroups (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    final List<dynamic> joinedGroups = data["items"];
    return joinedGroups
        .map((m) => JoinedGroup.fromJson(m))
        .toList();
  }

  Future<List<StudyGroupResponse>> listAllStudyGroups() async {
    final uri = Uri.parse("$baseUrl/group/");
    final resp = await http.get(uri);
    
    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to retrieve myStudyGroups (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    final List<dynamic> publicGroups = data["items"];
    return publicGroups
        .map((m) => StudyGroupResponse.fromJson(m))
        .toList();
  }

  Future<StudyGroupResponse> getStudyGroup(id) async {
    final uri = Uri.parse("$baseUrl/group/$id");
    final resp = await http.get(uri);

    if (resp.statusCode == 404) {
      throw Exception(
        'Looks like this study group document no longer exists..'
      );
    }
    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to retrieve StudyGroups (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    return StudyGroupResponse.fromJson(data);
  }

  Future<void> updateStudyGroup(StudyGroupResponse groupUpdated) async {
    String groupId = groupUpdated.id;

    final uri = Uri.parse("$baseUrl/group/$groupId");
    final resp = await http.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(groupUpdated.toJsonForName())
    );
    
    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to update StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  Future<void> leaveStudyGroup(groupId) async {
    final uri = Uri.parse("$baseUrl/group/$groupId/members/currentUser");
    final resp = await http.delete(uri);
    
    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to leave StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  Future<void> deleteStudyGroup(id) async {
    final uri = Uri.parse("$baseUrl/group/$id");
    final resp = await http.delete(uri);
    
    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to delete StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }
}
