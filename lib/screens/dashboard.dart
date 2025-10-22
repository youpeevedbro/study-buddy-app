import 'package:flutter/material.dart';
import 'package:study_buddy/components/square_button.dart';
import 'package:study_buddy/components/cursive_divider.dart';
import '../services/auth_service.dart';
import 'dart:async';


class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _userCheckedIn = true;
  int _secondsRemaining = 36; // dummy 
  Timer? _timer;
  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    _checkAuth();
      if (_userCheckedIn) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
    }
  }

  void _startTimer() {
    _endsAt ??= DateTime.now().add(const Duration(minutes: 60)); // Dummy code
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time's up! Let's make room for the next class.")),
        );
      }
    });
  }

  void _checkOutRoom() {
    setState(() {
      _userCheckedIn = false;
      _timer?.cancel();
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Hello, Student",
                  style: TextStyle(
                    fontFamily: "BrittanySignature",
                    fontSize: 65,
                  ),
                ),
                const SizedBox(height: 30),
                const SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: CursiveDivider(
                    color: Color(0xFFfcbf49),
                    strokeWidth: 10,
                  ),
                ),
                const SizedBox(height: 30),

                // --- top row ---
                Row(
                  children: [
                    SquareButton(
                      text: "Account\nSettings",
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                      backgroundColor: const Color(0xFFf79f79),
                    ),
                    const SizedBox(width: 30),
                    SquareButton(
                      text: "Find Study\nGroup",
                      onPressed: () {
                        Navigator.pushNamed(context, '/studygroup');
                      },
                      backgroundColor: const Color(0xFFf7d08a),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // --- bottom row ---
                Row(
                  children: [
                    SquareButton(
                      text: "Find\nRoom",
                      onPressed: () {
                        Navigator.pushNamed(context, '/rooms');
                      },
                      backgroundColor: const Color(0xFFbfd7b5),
                    ),
                    const SizedBox(width: 30),
                    SquareButton(
                      text: "My\nActivities",
                      onPressed: () {
                        Navigator.pushNamed(context, "/activities");
                      },
                      backgroundColor: const Color(0xFFffd6af),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // Timer widget
                if (_userCheckedIn)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 15),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDDD8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Color(0xFFE57373)),
                        const SizedBox(width: 8),
                        const Text(
                          'Timer',
                          style: TextStyle(
                            fontFamily: 'SuperLobster',
                            fontSize: 16,
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(_secondsRemaining),
                          style: const TextStyle(
                            fontFamily: 'SuperLobster',
                            fontSize: 18,
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                // === Check-out section ===
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _userCheckedIn
                      ? Row(
                          children: [
                            const SizedBox(width: 15),
                            const Text(
                              'Room Number',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: _checkOutRoom,
                              style: ElevatedButton.styleFrom(
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: "SuperLobster",
                                ),
                              ),
                              child: const Text("Check-out"),
                            ),
                            const SizedBox(width: 10),
                          ],
                        )
                      : const Center(
                          child: Text(
                            "You are currently not checked into a room",
                            style: TextStyle(
                              fontSize: 17,
                              fontFamily: 'SuperLobster',
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
