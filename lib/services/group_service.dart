// lib/services/group_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/group.dart';

import 'dart:io' show Platform; // REMOVE LATER
import 'package:flutter/foundation.dart' show kIsWeb; // REMOVE LATER

class GroupService {
  const GroupService();

  /// Base Cloud Run URL (from .env via AppConfig.init()).
  String get _base => AppConfig.apiBase;

  /// Build a Uri for group-related endpoints.
  Uri _u(String path, [Map<String, String>? qp]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    //return Uri.parse('$_base$normalized').replace(queryParameters: qp); //ADD BACK
    String temp_base = 'http://localhost:8000'; // REMOVE FOLLOWING
    if (kIsWeb) temp_base = 'http://localhost:8000';
    if (Platform.isAndroid) temp_base = 'http://10.0.2.2:8000';
    return Uri.parse('$temp_base$normalized').replace(queryParameters: qp);
  }

  /// Shared HTTP timeout for all backend calls.
  static const Duration _timeout = Duration(seconds: 30);

  /// Common headers, inject Firebase ID token if available.
  static Future<Map<String, String>> _headers() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    final token = await user?.getIdToken(); // non-forced, safe

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  } on FirebaseAuthException catch (e) {
    debugPrint("FirebaseAuthException in _headers(): ${e.code} - ${e.message}");

    // Return headers without token (backend will reject, but app won't crash)
    return {
      'Content-Type': 'application/json',
    };
  } catch (e) {
    debugPrint("Unexpected error in _headers(): $e");
    return {
      'Content-Type': 'application/json',
      };
    }
  }

  /// Extracts a clean message (usually FastAPI's "detail") for UI popups.
  String parseBackendError(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded.containsKey('detail')) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // ignore parse errors, fallback below
    }
    return body; // fallback
  }

  // ---------------------------------------------------------------------------
  // Core study-group CRUD
  // ---------------------------------------------------------------------------

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
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  Future<List<JoinedGroup>> listMyStudyGroups() async {
    final uri = _u('/group/myStudyGroups');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('listMyStudyGroups error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }

    final data = json.decode(resp.body);
    final List<dynamic> joinedGroups = data["items"];
    return joinedGroups.map((m) => JoinedGroup.fromJson(m)).toList();
  }

  Future<List<StudyGroupResponse>> listAllStudyGroups({String? name}) async {  //optional named parameter
    Map<String, String> qp = {};
    if (name != null && name.isNotEmpty) qp["name_filter"] = name;

    final uri = _u('/group/', qp);
    final resp =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('listAllStudyGroups error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
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
      // This one is already user-friendly
      throw Exception(
        'Looks like this study group document no longer exists..',
      );
    }
    if (resp.statusCode != 200) {
      debugPrint('getStudyGroup error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
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
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  Future<void> leaveStudyGroup(String groupId) async {
    final uri = _u('/group/$groupId/members/currentUser');
    final resp =
        await http.delete(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('leaveStudyGroup error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  Future<void> deleteStudyGroup(String id) async {
    final uri = _u('/group/$id');
    final resp =
        await http.delete(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('deleteStudyGroup error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  // ---------------------------------------------------------------------------
  // JOIN REQUESTS
  // ---------------------------------------------------------------------------

  /// Current user sends a join request for a given group.
  /// Backend: POST /group/{groupId}/requests/currentUser
  Future<void> sendJoinRequest(String groupId) async {
    final uri = _u('/group/$groupId/requests/currentUser');
    debugPrint('JOIN REQUEST URL = $uri');

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
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  /// For a study group that the current user owns, list incoming join requests.
  /// Backend: GET /group/{groupId}/requests
  Future<List<Map<String, dynamic>>> listIncomingRequests(
      String groupId) async {
    final uri = _u('/group/$groupId/requests');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint(
          'listIncomingRequests error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }

    final data = json.decode(resp.body);
    final List<dynamic> items = data["items"] ?? [];

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
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
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
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  /// Requester cancels their own join request OR owner declines a request.
  /// Backend: DELETE /group/{groupId}/requests/{userId}
  Future<void> cancelMyJoinRequest(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user!.uid;

    final uri = _u('/group/$groupId/requests/$uid');
    final resp =
        await http.delete(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      debugPrint('cancelMyJoinRequest error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  // ---------------------------------------------------------------------------
  // INVITES
  // ---------------------------------------------------------------------------

  Future<void> inviteByHandle(String groupId, String handle) async {
    final uri = _u('/group/$groupId/inviteByHandle');
    final resp = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({"handle": handle}),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('inviteByHandle error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  /// List all incoming invites for the current user.
  /// Backend: GET /group/myInvites
  Future<List<Map<String, dynamic>>> listMyIncomingInvites() async {
    final uri = _u('/group/myInvites');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode == 404) {
      debugPrint('listMyIncomingInvites: 404, treating as no invites.');
      return [];
    }

    if (resp.statusCode != 200) {
      debugPrint(
          'listMyIncomingInvites error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }

    final data = json.decode(resp.body);
    final List<dynamic> items = data["items"] ?? [];

    return items.map<Map<String, dynamic>>((item) {
      return {
        "groupId": item['groupId'],
        "groupName": item['groupName'],
        "ownerId": item['ownerId'],
        "ownerHandle": item['ownerHandle'],
        "ownerDisplayName": item['ownerDisplayName'],
        "inviteeId": item['inviteeId'],
      };
    }).toList();
  }

  /// Owner lists outgoing invites for a given group.
  /// Backend: GET /group/{groupId}/invites
  Future<List<Map<String, dynamic>>> listOutgoingInvites(
      String groupId) async {
    final uri = _u('/group/$groupId/invites');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(_timeout);

    if (resp.statusCode == 404) {
      debugPrint('listOutgoingInvites: 404, treating as no invites for group.');
      return [];
    }

    if (resp.statusCode != 200) {
      debugPrint('listOutgoingInvites error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }

    final data = json.decode(resp.body);
    final List<dynamic> items = data["items"] ?? [];

    return items.map<Map<String, dynamic>>((item) {
      return {
        "groupId": item['groupId'],
        "groupName": item['groupName'],
        "inviteeId": item['inviteeId'],
        "inviteeHandle": item['inviteeHandle'],
        "inviteeDisplayName": item['inviteeDisplayName'],
        "ownerId": item['ownerId'],
        "ownerHandle": item['ownerHandle'],
        "ownerDisplayName": item['ownerDisplayName'],
      };
    }).toList();
  }

  /// Invited user accepts an invite.
  /// Backend: POST /group/{groupId}/invites/{userId}/accept
  Future<void> acceptGroupInvite(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user!.uid;

    final uri = _u('/group/$groupId/invites/$uid/accept');
    final resp = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({}),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('acceptGroupInvite error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  /// Invited user declines OR owner cancels an invite.
  /// Backend: DELETE /group/{groupId}/invites/{userId}
  Future<void> declineOrCancelGroupInvite(
      String groupId, String userId) async {
    final uri = _u('/group/$groupId/invites/$userId');
    final resp = await http
        .delete(
          uri,
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      debugPrint(
          'declineOrCancelGroupInvite error: ${resp.statusCode} ${resp.body}');
      final msg = parseBackendError(resp.body);
      throw Exception(msg);
    }
  }

  //Look up building name 
  Future<String?> getBuildingName(String code) async {
  final snap = await FirebaseFirestore.instance
      .collection('buildings')
      .doc(code)
      .get();

  if (!snap.exists) return null;

  return snap.data()?['name'] as String?;
}

}
