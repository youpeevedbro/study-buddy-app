// lib/models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String handle;
  final String email;

  final bool checkedIn;
  final String? checkedInRoomId;
  final String? checkedInRoomLabel;
  final DateTime? checkedInEnd;

  final List<String> joinedStudyGroupIds;


  UserProfile({
    required this.uid,
    required this.displayName,
    required this.handle,
    required this.email,
    required this.checkedIn,
    required this.checkedInRoomId,
    required this.checkedInRoomLabel,
    required this.checkedInEnd,
    required this.joinedStudyGroupIds,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] ?? '',
      handle: data['handle'] ?? '',
      email: data['email'] ?? '',

      checkedIn: data['checkedIn'] ?? false,
      checkedInRoomId: data['checkedInRoomId'],
      checkedInRoomLabel: data['checkedInRoomLabel'],
      checkedInEnd: data['checkedInEnd'] != null
          ? (data['checkedInEnd'] as Timestamp).toDate()
          : null,

      joinedStudyGroupIds:
          List<String>.from(data['joinedStudyGroupIds'] ?? []),

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'handle': handle,
      'email': email,
    };
  }
}
