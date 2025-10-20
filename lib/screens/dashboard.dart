import 'package:flutter/material.dart';
import 'package:study_buddy/components/square_button.dart';
import 'package:study_buddy/components/cursive_divider.dart';
import '../services/auth_service.dart';


class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _userCheckedIn = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
    }
  }

  void _checkOutRoom() {
    setState(() {
      _userCheckedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // pushes bottom content down
            children: [
              Column(
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Hello, Student",
                    style:
                    TextStyle(fontFamily: "BrittanySignature", fontSize: 65),
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
                        onPressed: () {},
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
                ],
              ),

              Container(
                height: 60,
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
                    : Center(
                  child: Text(
                    "You are currently not checked into a room",
                    style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'SuperLobster',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
