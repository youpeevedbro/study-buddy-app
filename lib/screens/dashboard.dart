// lib/pages/dashboard.dart
import 'package:flutter/material.dart';
import 'package:study_buddy/components/square_button.dart';
import 'package:study_buddy/components/cursive_divider.dart';
import '../services/auth_service.dart';
import '../services/timer_service.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';      // 👈 NEW
import '../models/group.dart';               // 👈 for StudyGroupResponse
import 'dart:async';
import '../config/dev_config.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  bool _checkingOut = false;

  // 👇 NEW: activity count for the My Activities badge
  int _activityCount = 0;
  final GroupService _groupService = const GroupService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();

    // Rebuild when timer or check-in state changes
    TimerService.instance.addListener(_onExternalChange);
    CheckInService.instance.addListener(_onExternalChange);
    TimerService.instance.onTimerComplete = _autoCheckout;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 1) Stop any old countdown
      TimerService.instance.stop();

      // 2) Rehydrate from Firestore and restart timer based on end time
      _restoreCheckinFromProfile().then((_) async {
        // 3) Also refresh activity badge count when returning to app
        await _loadActivityCount();
        if (!mounted) return;
        setState(() {}); // ensure UI redraws
      });
    }
  }

  Future<void> _restoreCheckinFromProfile() async {
    final profile = await UserService.instance.getCurrentUserProfile();
    if (profile == null) {
      // no profile yet → nothing to restore
      return;
    }

    if (!profile.checkedIn) {
      // Make sure local state & timer are cleared
      CheckInService.instance.checkOut();
      return;
    }

    final end = profile.checkedInEnd;
    if (end == null) {
      // Bad / missing end time → clear state
      CheckInService.instance.checkOut();
      return;
    }

    final now = DevConfig.now();
    final remaining = end.difference(now).inSeconds;

    if (remaining <= 0) {
      // The slot already ended while the app was closed:
      // fix Firestore + local state
      await UserService.instance.checkOutFromRoom();
      CheckInService.instance.checkOut();
      return;
    }

    // Still checked in and time remaining > 0:
    // 1) Hydrate CheckInService (label, checkedIn flag)
    CheckInService.instance.hydrateFromProfile(profile);

    // 2) Restart the timer for the remaining duration
    TimerService.instance.start(Duration(seconds: remaining));
  }

  Future<void> _autoCheckout() async {
    try {
      // 1. Update Firestore
      await UserService.instance.checkOutFromRoom();

      // 2. Update local state
      CheckInService.instance.checkOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your session has ended. You have been checked out."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Auto-checkout failed: $e"),
        ),
      );
    }
  }

  void _onExternalChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TimerService.instance.removeListener(_onExternalChange);
    CheckInService.instance.removeListener(_onExternalChange);
    TimerService.instance.onTimerComplete = null;
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
    } else {
      // After confirming login, restore check-in state if needed
      await _restoreCheckinFromProfile();
      // Also load initial activity count for badge
      await _loadActivityCount();
      if (!mounted) return;
      setState(() {}); // ensure UI reflects restored state
    }
  }

  // 👇 NEW: compute how many incoming items exist (join requests + invites)
  Future<void> _loadActivityCount() async {
    try {
      // 1) Get all groups (for ownership)
      final List<StudyGroupResponse> allGroups =
          await _groupService.listAllStudyGroups();

      int incoming = 0;

      // 2) For each group I own, count join requests
      for (final g in allGroups) {
        if (g.access == "owner") {
          final reqs = await _groupService.listIncomingRequests(g.id);
          incoming += reqs.length;
        }
      }

      // 3) Invites sent TO ME
      final myInvites = await _groupService.listMyIncomingInvites();
      incoming += myInvites.length;

      if (!mounted) return;
      setState(() {
        _activityCount = incoming;
      });
    } catch (_) {
      // You can add debugPrint here if you want; silently ignore for now.
    }
  }

  Future<void> _checkOutRoom() async {
    if (_checkingOut) return; // prevents double-taps

    setState(() => _checkingOut = true);

    try {
      // 1) Update Firestore user document
      await UserService.instance.checkOutFromRoom();

      // 2) Update local in-memory service + stop timer
      CheckInService.instance.checkOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You have checked out of your current room."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to check out: $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingOut = false);
      }
    }
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return "$hh:$mm:$ss"; // e.g. 07:59:41
    } else {
      return "$mm:$ss"; // e.g. 59:41
    }
  }

  LinearGradient get _brandGradient => const LinearGradient(
        colors: [
          Color(0xFFFFDE59),
          Color(0xFFFF914D),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedIn = CheckInService.instance.checkedIn;
    final currentRoom = CheckInService.instance.currentRoom;
    final currentLabel = CheckInService.instance.currentRoomLabel;

    // Show building + room (e.g., ECS-228B) when checked in
    final roomLabel = currentRoom != null
        ? "${currentRoom.buildingCode}-${currentRoom.roomNumber}"
        : (currentLabel ?? "Room Number");

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // ===== Header card with cursive =====
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E0),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Hello, Student",
                        style: TextStyle(
                          fontFamily: "BrittanySignature",
                          fontSize: 52, // slightly smaller but still cursive
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Welcome back! Let’s find a room or join a study group.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: CursiveDivider(
                    color: Color(0xFFfcbf49),
                    strokeWidth: 8,
                  ),
                ),

                const SizedBox(height: 24),

                // ===== Top row: Account & Study Group =====
                Row(
                  children: [
                    Expanded(
                      child: SquareButton(
                        text: "Account\nSettings",
                        onPressed: () =>
                            Navigator.pushNamed(context, '/profile'),
                        backgroundColor: const Color(0xFFF8C4B4),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SquareButton(
                        text: "Find Study\nGroup",
                        onPressed: () =>
                            Navigator.pushNamed(context, '/studygroup'),
                        backgroundColor: const Color(0xFFFEE1A8),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ===== Bottom row: Find Room & My Activities (with badge) =====
                Row(
                  children: [
                    Expanded(
                      child: SquareButton(
                        text: "Find\nRoom",
                        onPressed: () =>
                            Navigator.pushNamed(context, '/rooms'),
                        backgroundColor: const Color(0xFFBFD7B5),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SquareButton(
                            text: "My\nActivities",
                            onPressed: () async {
                              await Navigator.pushNamed(
                                  context, "/activities");
                              // After returning, reload counts
                              await _loadActivityCount();
                            },
                            backgroundColor: const Color(0xFFFFD6AF),
                          ),
                          if (_activityCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _activityCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ===== Timer widget (visible only when checked in) =====
                if (checkedIn)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 15),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFCCBC),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Color(0xFFE57373)),
                        const SizedBox(width: 8),
                        const Text(
                          'Timer',
                          style: TextStyle(
                            fontFamily: 'SuperLobster',
                            fontSize: 18,
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(TimerService.instance.secondsRemaining),
                          style: const TextStyle(
                            fontFamily: 'SuperLobster',
                            fontSize: 20,
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // ===== Check-out / info section =====
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
