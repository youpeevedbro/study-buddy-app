class UserProfile {
  final String uid;
  final String handle;
  final String displayName;
  final String email;

  UserProfile({
    required this.uid,
    required this.handle,
    required this.displayName,
    required this.email,
  });

  // Used when creating/updating profile
  Map<String, dynamic> toJson() {
    return {
      'handle': handle,
      'displayName': displayName,
      'email': email,
    };
  }

  // Used when reading from Firestore
  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      handle: data['handle'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
    );
  }
}
