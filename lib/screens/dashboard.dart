// lib/pages/dashboard.dart
import 'package:flutter/material.dart';
import 'package:study_buddy/components/square_button.dart';
import 'package:study_buddy/components/cursive_divider.dart';
import '../services/auth_service.dart';
import '../services/timer_service.dart';
import '../services/checkin_service.dart';
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
    // Rebuild when timer or check-in state changes
    TimerService.instance.addListener(_onExternalChange);
    CheckInService.instance.addListener(_onExternalChange);
  }

  void _onExternalChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_onExternalChange);
    CheckInService.instance.removeListener(_onExternalChange);
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
    }
  }

  void _checkOutRoom() {
    CheckInService.instance.checkOut(); // flips to false + stops timer
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedIn = CheckInService.instance.checkedIn;
    final currentRoom = CheckInService.instance.currentRoom;

    // Show building + room (e.g., ECS-228B) when checked in
    final roomLabel = currentRoom != null
        ? "${currentRoom.buildingCode}-${currentRoom.roomNumber}"
        : "Room Number";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
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
                  textAlign: TextAlign.center,
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

                // === Top row ===
                Row(
                  children: [
                    Expanded(
                      child: SquareButton(
                        text: "Account\nSettings",
                        onPressed: () => Navigator.pushNamed(context, '/profile'),
                        backgroundColor: const Color(0xFFf79f79),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: SquareButton(
                        text: "Find Study\nGroup",
                        onPressed: () => Navigator.pushNamed(context, '/studygroup'),
                        backgroundColor: const Color(0xFFf7d08a),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // === Bottom row ===
                Row(
                  children: [
                    Expanded(
                      child: SquareButton(
                        text: "Find\nRoom",
                        onPressed: () => Navigator.pushNamed(context, '/rooms'),
                        backgroundColor: const Color(0xFFbfd7b5),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: SquareButton(
                        text: "My\nActivities",
                        onPressed: () => Navigator.pushNamed(context, "/activities"),
                        backgroundColor: const Color(0xFFffd6af),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // === Timer widget (visible only when checked in) ===
                if (checkedIn)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
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
                          _formatTime(TimerService.instance.secondsRemaining),
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

                // === Check-out / info section ===
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: checkedIn
                      ? Row(
                    children: [
                      const SizedBox(width: 15),
                      Text(
                        roomLabel, // ECS-228B
                        style: const TextStyle(
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
