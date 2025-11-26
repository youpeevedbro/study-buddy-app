// lib/services/checkin_service.dart
import 'package:flutter/foundation.dart';
import '../models/room.dart';
import 'timer_service.dart';
import '../models/user_profile.dart';

/// Global single source of truth for user check-in state.
class CheckInService extends ChangeNotifier {
  CheckInService._();
  static final CheckInService instance = CheckInService._();

  bool _checkedIn = false;
  Room? _currentRoom;
  String? _currentRoomLabel;
  String? _currentRoomId;   // 👈 NEW

  bool get checkedIn => _checkedIn;
  Room? get currentRoom => _currentRoom;
  String? get currentRoomLabel => _currentRoomLabel;
  String? get currentRoomId => _currentRoomId;

  /// Check into a room/time slot.
  void checkIn({required Room room}) {
    _checkedIn = true;
    _currentRoom = room;
    _currentRoomId = room.id;  // 👈 track id
    _currentRoomLabel = '${room.buildingCode}-${room.roomNumber}';
    notifyListeners();
  }

  /// Check out from the current room and stop the timer.
  void checkOut() {
    _checkedIn = false;
    _currentRoom = null;
    _currentRoomId = null;     // 👈 reset id
    _currentRoomLabel = null;
    TimerService.instance.stop();
    notifyListeners();
  }

  /// Does the given room/time slot equal the currently checked-in slot?
  bool isCurrentRoom(Room r) {
    if (!_checkedIn) return false;

    // Prefer id comparison if we have it
    if (_currentRoomId != null && r.id.isNotEmpty) {
      return r.id == _currentRoomId;
    }

    // Fallback: compare fields if we still have the Room object
    if (_currentRoom != null) {
      return _currentRoom!.buildingCode == r.buildingCode &&
          _currentRoom!.roomNumber == r.roomNumber &&
          _currentRoom!.date == r.date &&
          _currentRoom!.start == r.start &&
          _currentRoom!.end == r.end;
    }

    return false;
  }

  /// Restore check-in state from a UserProfile (e.g., app restart).
  void hydrateFromProfile(UserProfile profile) {
    _checkedIn = profile.checkedIn;

    if (_checkedIn) {
      _currentRoom = null; // we don't know the full Room object yet
      _currentRoomId = profile.checkedInRoomId;        // 👈 use stored id
      _currentRoomLabel = profile.checkedInRoomLabel;  // existing field
    } else {
      _currentRoom = null;
      _currentRoomId = null;
      _currentRoomLabel = null;
    }

    notifyListeners();
  }
}
