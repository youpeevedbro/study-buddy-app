// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../models/room.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _slotsCol =>
    _firestore.collection('availabilitySlots');

  Future<void> _bumpSlotCheckins(String slotId, int delta) async {
    if (slotId.isEmpty) return;
    await _slotsCol.doc(slotId).update({
      'currentCheckins': FieldValue.increment(delta),
    });
  }

  /// Compute when this slot ends as a DateTime, or null if parsing fails.
  DateTime? _computeCheckedInEnd(Room room) {
    try {
      if (room.date.isEmpty || room.end.isEmpty) return null;

      final dateParts = room.date.split('-');
      if (dateParts.length != 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final timeParts = room.end.split(':');
      if (timeParts.length != 2) return null;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Check the current user into a given room/time slot.
  Future<void> checkInToRoom(Room room) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is logged in.');
    }

    final uid = user.uid;
    final end = _computeCheckedInEnd(room);

    // Read current user doc so we can decrement previous slot if needed
    final userDoc = await _usersCol.doc(uid).get();
    final data = userDoc.data();
    final bool wasCheckedIn = data?['checkedIn'] as bool? ?? false;
    final String? prevSlotId = data?['checkedInRoomId'] as String?;

    // 🔒 Guard: if they're already checked into THIS slot, do nothing
    if (wasCheckedIn && prevSlotId == room.id) {
      // Optional: you *could* refresh checkedInEnd here if you ever wanted
      // to extend/repair the end time, but for now it's a no-op.
      return;
    }

    // Update user doc for the NEW check-in
    await _usersCol.doc(uid).update({
      'checkedIn': true,
      'checkedInRoomId': room.id,
      'checkedInRoomLabel': '${room.buildingCode}-${room.roomNumber}',
      'checkedInEnd': end != null ? Timestamp.fromDate(end) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Bump counters
    if (wasCheckedIn &&
        prevSlotId != null &&
        prevSlotId.isNotEmpty &&
        prevSlotId != room.id) {
      await _bumpSlotCheckins(prevSlotId, -1);
    }
    await _bumpSlotCheckins(room.id, 1);
  }



  /// Check the current user out of whatever room they're in.
  Future<void> checkOutFromRoom() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is logged in.');
    }

    final uid = user.uid;

    // Grab current slot id BEFORE we clear it
    final userDoc = await _usersCol.doc(uid).get();
    final data = userDoc.data();
    final String? slotId = data?['checkedInRoomId'] as String?;

    // Clear user check-in state
    await _usersCol.doc(uid).update({
      'checkedIn': false,
      'checkedInRoomId': null,
      'checkedInRoomLabel': null,
      'checkedInEnd': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Decrement slot count if we had one
    if (slotId != null && slotId.isNotEmpty) {
      await _bumpSlotCheckins(slotId, -1);
    }
  }


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

    // 2) Build UserProfile with all required fields
    final profile = UserProfile(
      uid: user.uid,
      displayName: displayName,
      handle: handle,
      email: user.email ?? '',

      // new fields:
      checkedIn: false,
      checkedInRoomId: null,
      checkedInRoomLabel: null,
      checkedInEnd: null,
      joinedStudyGroupIds: const [],
    );

    // 3) Write to Firestore
    await _usersCol.doc(user.uid).set({
      ...profile.toJson(),
      'checkedIn': profile.checkedIn,
      'checkedInRoomId': profile.checkedInRoomId,
      'checkedInRoomLabel': profile.checkedInRoomLabel,
      'checkedInEnd': profile.checkedInEnd,
      'joinedStudyGroupIds': profile.joinedStudyGroupIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  /// Update the current user's handle (username) with uniqueness check.
  Future<void> updateCurrentUserHandle(String newHandle) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is logged in.');
    }

    newHandle = newHandle.trim();

    // basic format check (same as create profile)
    final valid = RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(newHandle);
    if (!valid) {
      throw Exception(
          'Handle must be 3–20 characters: letters, numbers, underscores only.');
    }

    // If handle unchanged, nothing to do
    final currentDoc = await _usersCol.doc(user.uid).get();
    final currentData = currentDoc.data();
    if (currentData != null && currentData['handle'] == newHandle) {
      return;
    }

    // uniqueness check
    final available = await isHandleAvailable(newHandle);
    if (!available) {
      throw Exception('Handle already taken. Try another.');
    }

    // update Firestore
    await _usersCol.doc(user.uid).update({
      'handle': newHandle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently delete the current user's account.
  /// This will:
  ///   1. Delete Firestore users/{uid}
  ///   2. Delete the Firebase Auth user
  Future<void> deleteCurrentUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is logged in.');
    }

    final uid = user.uid;

    // 1) Delete Firestore profile document
    await _usersCol.doc(uid).delete();

    // 2) Delete the Firebase Auth user
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // Firebase can require recent login for sensitive actions like delete().
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security reasons, please sign out and log in again before deleting your account.',
        );
      }
      rethrow;
    }
  }

  /// Update both displayName and handle for the current user.
  Future<void> updateDisplayNameAndHandle({
    required String newDisplayName,
    required String newHandle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is logged in.');
    }

    newDisplayName = newDisplayName.trim();
    newHandle = newHandle.trim();

    if (newDisplayName.isEmpty) {
      throw Exception('Display name cannot be empty.');
    }

    // Validate handle format
    final valid = RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(newHandle);
    if (!valid) {
      throw Exception(
        'Handle must be 3–20 characters: letters, numbers, underscores only.',
      );
    }

    final doc = await _usersCol.doc(user.uid).get();
    final currentData = doc.data() ?? {};
    final currentHandle = currentData['handle'] as String? ?? '';

    // Only check uniqueness if the handle actually changed
    if (currentHandle != newHandle) {
      final available = await isHandleAvailable(newHandle);
      if (!available) {
        throw Exception('Handle already taken. Try another.');
      }
    }

    await _usersCol.doc(user.uid).update({
      'displayName': newDisplayName,
      'handle': newHandle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
