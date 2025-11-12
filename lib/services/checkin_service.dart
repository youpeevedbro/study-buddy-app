// lib/services/checkin_service.dart
import 'package:flutter/foundation.dart';
import '../models/room.dart';
import 'timer_service.dart';

/// Global single source of truth for user check-in state.
class CheckInService extends ChangeNotifier {
  CheckInService._();
  static final CheckInService instance = CheckInService._();

  bool _checkedIn = false;
  Room? _currentRoom;

  bool get checkedIn => _checkedIn;
  Room? get currentRoom => _currentRoom;

  /// Check into a room/time slot.
  void checkIn({required Room room}) {
    _checkedIn = true;
    _currentRoom = room;
    notifyListeners();
  }

  /// Check out from the current room and stop the timer.
  void checkOut() {
    _checkedIn = false;
    _currentRoom = null;
    TimerService.instance.stop(); // keep your previous behavior
    notifyListeners();
  }

  /// Does the given room/time slot equal the currently checked-in slot?
  bool isCurrentRoom(Room r) {
    if (_currentRoom == null) return false;

    // If your Room has a unique id, compare that instead.
    return _currentRoom!.buildingCode == r.buildingCode &&
        _currentRoom!.roomNumber == r.roomNumber &&
        _currentRoom!.date == r.date &&
        _currentRoom!.start == r.start &&
        _currentRoom!.end == r.end;
  }
}
