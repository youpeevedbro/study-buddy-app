import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  TimerService._();
  static final TimerService instance = TimerService._();

  Timer? _timer;
  int _secondsRemaining = 0;

  bool get isActive => _secondsRemaining > 0;
  int get secondsRemaining => _secondsRemaining;

  void start(Duration duration) {
    _timer?.cancel();
    _secondsRemaining = duration.inSeconds;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        stop();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _secondsRemaining = 0;
    notifyListeners();
  }
}