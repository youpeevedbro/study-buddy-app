// lib/config/dev_config.dart

// TODO(Timer Testing Guide):
// ------------------------------------------------------------
// We support fake time via DevConfig.now() for easier testing.
// BUT certain cases should only be tested using REAL TIME.
//
// USE FAKE TIME (DevConfig.debug = true) FOR:
//  1. Auto-checkout when timer hits 0
//     - e.g., set fake time to 08:59 for a slot ending at 09:00.
//     - Check in → timer starts at ~60s → hits zero → auto-checkout.
//  2. Cold start AFTER the slot has ended
//     - Set fake time to AFTER the end time.
//     - Launch the app → Dashboard should auto-checkout immediately.
//
// USE REAL TIME (DevConfig.debug = false) FOR:
//  3. Suspend app shortly after check-in → resume
//     - Timer should continue decreasing (no resets).
//  4. Suspend app until after the timer ends → resume
//     - Auto-checkout should fire on resume.
//  5. Close app → cold start shortly after check-in
//     - Timer should pick up where it left off.
//
// Why?
// Fake time is STATIC and does not advance while the app is backgrounded.
// On resume, the rehydration logic recomputes remaining time using
// endTime - DevConfig.now(), which can make timers appear to “reset”.
// ------------------------------------------------------------

class DevConfig {
  static bool debug = true; // set true to enable fake time
  static DateTime? _fakeTime;

  /// Optional static setters:
  static void setFakeTime(DateTime dt) {
    debug = true;
    _fakeTime = dt;
  }

  static void useRealTime() {
    debug = false;
    _fakeTime = null;
  }

  static DateTime now() {
    if (debug && _fakeTime != null) {
      return _fakeTime!;
    }
    return DateTime.now();
  }

  /// ------------------------------------------------------------
  /// NEW: Pretty printer so dev console shows what's going on.
  /// ------------------------------------------------------------
  static void printDebugInfo() {
    if (debug) {
      print('''

==================== DevConfig DEBUG MODE ====================
 FAKE TIME ENABLED
 Current fake time: $_fakeTime
 NOTE: Fake time does NOT advance while app is suspended.
==============================================================

''');
    } else {
      print('''

==================== DevConfig ====================
 Using REAL device/system time: ${DateTime.now()}
===================================================

''');
    }
  }
}

