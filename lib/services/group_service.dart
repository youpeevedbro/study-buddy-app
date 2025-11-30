// lib/services/group_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/group.dart';

class GroupService {
  const GroupService();

  /// Base Cloud Run URL (from .env via AppConfig.init()).
  String get _base => AppConfig.apiBase;

  /// Build a Uri for group-related endpoints.
  Uri _u(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_base$normalized');
  }

  /// Shared HTTP timeout for all backend calls.
  static const Duration _timeout = Duration(seconds: 30);

  /// Common headers, inject Firebase ID token if available.
  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken(true);
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }


  Future<void> createStudyGroup(SelectedGroupFields group) async {
    final uri = _u('/group/'); // Cloud Run / FastAPI endpoint
    final resp = await http
        .post(
      uri,
      headers: await _headers(),
      body: jsonEncode(group.toJson()),
    )
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('createStudyGroup error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to create StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  Future<List<JoinedGroup>> listMyStudyGroups() async {
    final uri = _u('/group/myStudyGroups');
    final resp =
    await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('listMyStudyGroups error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to retrieve myStudyGroups (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    final List<dynamic> joinedGroups = data["items"];
    return joinedGroups.map((m) => JoinedGroup.fromJson(m)).toList();
  }

  Future<List<StudyGroupResponse>> listAllStudyGroups() async {
    final uri = _u('/group/');
    final resp =
    await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('listAllStudyGroups error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to retrieve StudyGroups (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    final List<dynamic> publicGroups = data["items"];
    return publicGroups.map((m) => StudyGroupResponse.fromJson(m)).toList();
  }

  Future<StudyGroupResponse> getStudyGroup(String id) async {
    final uri = _u('/group/$id');
    final resp =
    await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode == 404) {
      throw Exception(
        'Looks like this study group document no longer exists..',
      );
    }
    if (resp.statusCode != 200) {
      debugPrint('getStudyGroup error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to retrieve StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    return StudyGroupResponse.fromJson(data);
  }

  Future<void> updateStudyGroup(StudyGroupResponse groupUpdated) async {
    final String groupId = groupUpdated.id;
    final uri = _u('/group/$groupId');

    final resp = await http
        .patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(groupUpdated.toJsonForName()),
    )
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('updateStudyGroup error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to update StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  Future<void> leaveStudyGroup(String groupId) async {
    final uri = _u('/group/$groupId/members/currentUser');
    final resp =
    await http.delete(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('leaveStudyGroup error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to leave StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  Future<void> deleteStudyGroup(String id) async {
    final uri = _u('/group/$id');
    final resp =
    await http.delete(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('deleteStudyGroup error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to delete StudyGroup (${resp.statusCode}): ${resp.body}',
      );
    }
  }
  
// ------------------------------------------------------------
  // JOIN REQUESTS
  // ------------------------------------------------------------

  /// Current user sends a join request for a given group.
  /// Backend: POST /group/{groupId}/requests/currentUser
Future<void> sendJoinRequest(String groupId) async {
  final uri = _u('/group/$groupId/requests/currentUser');
  debugPrint('JOIN REQUEST URL = $uri');  // 👈 add this

  final resp = await http
      .post(
        uri,
        headers: await _headers(),
        body: jsonEncode({}),
      )
      .timeout(_timeout);

  if (resp.statusCode != 200 && resp.statusCode != 201) {
    debugPrint('sendJoinRequest status: ${resp.statusCode}');
    debugPrint('sendJoinRequest body: ${resp.body}');
    throw Exception(
      'Failed to send join request (${resp.statusCode}): ${resp.body}',
    );
  }
}


  /// For a study group that the current user owns, list incoming join requests.
  /// Backend: GET /group/{groupId}/requests
  Future<List<Map<String, dynamic>>> listIncomingRequests(String groupId) async {
    final uri = _u('/group/$groupId/requests');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint(
          'listIncomingRequests error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to retrieve incoming requests (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = json.decode(resp.body);
    final List<dynamic> items = data["items"] ?? [];

    // map to the shape expected by MyActivitiesPage
    return items.map<Map<String, dynamic>>((item) {
      return {
        "groupId": item['groupId'],
        "groupName": item['groupName'],
        "requesterId": item['requesterId'],
        "requesterHandle": item['requesterHandle'],
        "requesterName": item['requesterDisplayName'],
      };
    }).toList();
  }

  /// Owner accepts a join request → add user as member.
  /// Backend: POST /group/{groupId}/members/{requesterId}
  Future<void> acceptIncomingRequest({
    required String groupId,
    required String requesterId,
  }) async {
    final uri = _u('/group/$groupId/members/$requesterId');
    final resp = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({}),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      debugPrint(
          'acceptIncomingRequest error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to accept join request (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// Owner declines a join request → delete incomingRequests/{requesterId}.
  /// Backend: DELETE /group/{groupId}/requests/{requesterId}
  Future<void> declineIncomingRequest({
    required String groupId,
    required String requesterId,
  }) async {
    final uri = _u('/group/$groupId/requests/$requesterId');
    final resp = await http
        .delete(
          uri,
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      debugPrint(
          'declineIncomingRequest error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to decline join request (${resp.statusCode}): ${resp.body}',
      );
    }
  }

}



  