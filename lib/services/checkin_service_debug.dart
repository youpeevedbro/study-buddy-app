// DEBUG-ONLY VERSION
// Drop-in replacement for `lib/services/checkin_service.dart` while testing.
// Purpose: ignore stale/incorrect `date` values and base countdown on TODAY's time
// so you can verify UI and timer behavior even when the room date is in the past.
//
// Usage (temporary):
// 1) In files that currently import '../services/checkin_service.dart',
//    change the import to:
//       import '../services/checkin_service_debug.dart';
// 2) The class name remains `CheckInService`, so no other code changes are needed.
// 3) Revert the import when done testing and delete this file.

import 'package:flutter/foundation.dart';
import '../models/room.dart';
import 'timer_service.dart';

/// DEBUG: Global single source of truth for user check-in state.
/// This version REBASES time to TODAY and ignores `room.date`.
class CheckInService extends ChangeNotifier {
  CheckInService._();
  static final CheckInService instance = CheckInService._();

  bool _checkedIn = false;
  Room? _currentRoom;

  bool get checkedIn => _checkedIn;
  Room? get currentRoom => _currentRoom;

  /// Check into a room/time slot.
  ///
  /// Behavior (debug):
  /// - If `end` (HH:mm) is present, countdown to today's `end` time.
  /// - Else if `start` (HH:mm) is present, assume a 60-minute session from today's start.
  /// - Else default to a 60-minute countdown.
  /// - Negative diffs clamp to zero.
  void checkIn({required Room room}) {
    _checkedIn = true;
    _currentRoom = room;

    Duration remainingDuration = Duration.zero;

    try {
      final now = DateTime.now();

      int? _hmToMinutes(String s) {
        final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s.trim());
        if (m == null) return null;
        final h = int.tryParse(m.group(1)!);
        final mm = int.tryParse(m.group(2)!);
        if (h == null || mm == null) return null;
        if (h < 0 || h > 23 || mm < 0 || mm > 59) return null;
        return h * 60 + mm;
      }

      DateTime? endDateTime;

      if (room.end.isNotEmpty) {
        final mins = _hmToMinutes(room.end);
        if (mins != null) {
          final h = mins ~/ 60, m = mins % 60;
          endDateTime = DateTime(now.year, now.month, now.day, h, m);
        } else {
          debugPrint('CheckInService[DEBUG]: could not parse end "${room.end}"');
        }
      } else if (room.start.isNotEmpty) {
        final mins = _hmToMinutes(room.start);
        if (mins != null) {
          final h = mins ~/ 60, m = mins % 60;
          final startDT = DateTime(now.year, now.month, now.day, h, m);
          endDateTime = startDT.add(const Duration(minutes: 60));
        } else {
          debugPrint('CheckInService[DEBUG]: could not parse start "${room.start}"');
        }
      }

      if (endDateTime != null) {
        final diff = endDateTime.difference(now);
        remainingDuration = diff.isNegative ? Duration.zero : diff;
      } else {
        debugPrint('CheckInService[DEBUG]: Missing/invalid times; defaulting to 60-minute countdown');
        remainingDuration = const Duration(minutes: 60);
      }
    } catch (e) {
      debugPrint('CheckInService[DEBUG]: time calculation error: $e');
      remainingDuration = Duration.zero;
    }

    // Start countdown
    TimerService.instance.start(remainingDuration);

    notifyListeners();
  }

  /// Check out from the current room and stop the timer.
  void checkOut() {
    _checkedIn = false;
    _currentRoom = null;

    TimerService.instance.stop();

    notifyListeners();
  }

  /// Does the given room/time slot equal the currently checked-in slot?
  bool isCurrentRoom(Room r) {
    if (_currentRoom == null) return false;
    return _currentRoom!.id == r.id;
  }
}
