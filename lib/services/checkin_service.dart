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

    // ===== TIME CALCULATION LOGIC =====

    Duration remainingDuration = Duration.zero;

    try {
      // Build a date string. If missing, assume today.
      final now = DateTime.now();
      final dateStr = (room.date.isNotEmpty)
          ? room.date
          : "${now.year.toString().padLeft(4, '0')}-"
            "${now.month.toString().padLeft(2, '0')}-"
            "${now.day.toString().padLeft(2, '0')}";

      DateTime? endDateTime;

      if (room.end.isNotEmpty) {
        // Prefer explicit end time when available
        endDateTime = DateTime.tryParse("${dateStr}T${room.end}:00");
        if (endDateTime == null) {
          debugPrint(
              'CheckInService: Failed to parse end time "${room.end}" for date "$dateStr"');
        }
      } else if (room.start.isNotEmpty) {
        // If no end but we have a start, default to 60 minutes session
        final startDT = DateTime.tryParse("${dateStr}T${room.start}:00");
        if (startDT != null) {
          endDateTime = startDT.add(const Duration(minutes: 60));
        } else {
          debugPrint(
              'CheckInService: Failed to parse start time "${room.start}" for date "$dateStr"');
        }
      }

      if (endDateTime != null) {
        final diff = endDateTime.difference(now);
        remainingDuration = diff.isNegative ? Duration.zero : diff;
      } else {
        // As a last resort, start a 60-minute countdown so the UI is responsive
        debugPrint(
            'CheckInService: Missing start/end; defaulting to 60-minute countdown');
        remainingDuration = const Duration(minutes: 60);
      }
    } catch (e) {
      // If parsing fails, default to 0 and log
      debugPrint('CheckInService: time calculation error: $e');
      remainingDuration = Duration.zero;
    }

    // ===== START TIMER =====
    TimerService.instance.start(remainingDuration);

    notifyListeners();
  }

  /// Check out from the current room and stop the timer.
  void checkOut() {
    _checkedIn = false;
    _currentRoom = null;

    TimerService.instance.stop(); // stop countdown

    notifyListeners();
  }

  /// Does the given room/time slot equal the currently checked-in slot?
  bool isCurrentRoom(Room r) {
    if (_currentRoom == null) return false;

    // If your Room has a unique id, using id is best.
    return _currentRoom!.id == r.id;
  }
}
