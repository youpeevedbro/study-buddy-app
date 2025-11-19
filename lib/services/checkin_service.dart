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

    Duration remainingDuration = Duration.zero;

    try {
      final now = DateTime.now();
      DateTime _today() => DateTime(now.year, now.month, now.day);

      // Flexible date parsing: supports ISO (yyyy-mm-dd), M/D/YYYY, YYYY/M/D. Falls back to today.
      DateTime _parseDateFlexible(String s) {
        final raw = s.trim();
        final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        final mdY = RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$');
        final yMdSlash = RegExp(r'^\d{4}/\d{1,2}/\d{1,2}$');
        try {
          if (iso.hasMatch(raw)) return DateTime.parse(raw);
          if (mdY.hasMatch(raw)) {
            final p = raw.split('/');
            return DateTime(int.parse(p[2]), int.parse(p[0]), int.parse(p[1]));
          }
          if (yMdSlash.hasMatch(raw)) {
            final p = raw.split('/');
            return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
          }
          final tryDt = DateTime.tryParse(raw);
          if (tryDt != null) return DateTime(tryDt.year, tryDt.month, tryDt.day);
        } catch (_) {
          // fall through
        }
        return _today();
      }

      // Strict HH:mm parsing (accepts 9:05 or 09:05)
      int? _parseHm(String s) {
        final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(s);
        if (m == null) return null;
        final h = int.tryParse(m.group(1)!);
        final mm = int.tryParse(m.group(2)!);
        if (h == null || mm == null) return null;
        if (h < 0 || h > 23 || mm < 0 || mm > 59) return null;
        return h * 60 + mm;
      }

      final baseDate = room.date.isNotEmpty ? _parseDateFlexible(room.date) : _today();

      DateTime? endDateTime;

      if (room.end.isNotEmpty) {
        final mins = _parseHm(room.end);
        if (mins != null) {
          final h = mins ~/ 60, m = mins % 60;
          endDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
        } else {
          debugPrint('CheckInService: could not parse end "${room.end}"');
        }
      } else if (room.start.isNotEmpty) {
        final mins = _parseHm(room.start);
        if (mins != null) {
          final h = mins ~/ 60, m = mins % 60;
          final startDT = DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
          endDateTime = startDT.add(const Duration(minutes: 60));
        } else {
          debugPrint('CheckInService: could not parse start "${room.start}"');
        }
      }

      if (endDateTime != null) {
        final diff = endDateTime.difference(now);
        remainingDuration = diff.isNegative ? Duration.zero : diff;
      } else {
        debugPrint('CheckInService: Missing/invalid times; defaulting to 60-minute countdown');
        remainingDuration = const Duration(minutes: 60);
      }
    } catch (e) {
      debugPrint('CheckInService: time calculation error: $e');
      remainingDuration = Duration.zero;
    }

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

  bool isCurrentRoom(Room r) {
    if (_currentRoom == null) return false;
    return _currentRoom!.id == r.id;
  }
}