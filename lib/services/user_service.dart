// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  /// Check if the current logged-in user already has a profile doc.
  Future<bool> currentUserProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _usersCol.doc(user.uid).get();
    return doc.exists;
  }

  /// Get the current user's profile, or null if it doesn't exist yet.
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _usersCol.doc(user.uid).get();
    if (!doc.exists) return null;

    return UserProfile.fromFirestore(user.uid, doc.data()!);
  }

  /// Check if a handle is available (unique).
  Future<bool> isHandleAvailable(String handle) async {
    final snap = await _usersCol
        .where('handle', isEqualTo: handle)
        .limit(1)
        .get();

    return snap.docs.isEmpty;
  }

  /// Create the profile for the current user (first-time login).
  Future<void> createCurrentUserProfile({
    required String handle,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is logged in.');
    }

    // 1) Check handle uniqueness
    final available = await isHandleAvailable(handle);
    if (!available) {
      throw Exception('Handle already taken');
    }

    final profile = UserProfile(
      uid: user.uid,
      handle: handle,
      displayName: displayName,
      email: user.email ?? '',
    );

    // 2) Write to Firestore
    await _usersCol.doc(user.uid).set({
      ...profile.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'checkedIn': false,
      'disableAccount': false,
    });
  }
}
