// lib/pages/dashboard.dart
import 'package:flutter/material.dart';
import 'package:study_buddy/components/cursive_divider.dart';
import '../services/auth_service.dart';
import '../services/timer_service.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../components/grad_button.dart';
import 'dart:async';
import 'dart:ui';
import '../config/dev_config.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  bool _checkingOut = false;

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
      _restoreCheckinFromProfile().then((_) {
        if (!mounted) return;
        setState(() {}); // just to be extra sure UI redraws
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
          content:
              Text("Your session has ended. You have been checked out."),
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
      if (!mounted) return;
      setState(() {}); // ensure UI reflects restored state
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
      SnackBar(
        content: const Text(
          "You have checked out of your current room.",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF81C784),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        duration: const Duration(seconds: 2),
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

  // ---- UI HELPERS (layout only, no logic changes) ----

 Widget _buildActionCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color accent,   
  required VoidCallback onTap,
}) {
  // light pastel background based on accent
  final bg = Color.lerp(accent, Colors.white, 0.75)!; // still pastel but lighter

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Ink(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color.lerp(accent, Colors.white, 0.4)!),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(45), // soft colored shadow
            offset: const Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accent.withAlpha(50),
            child: Icon(
              icon,
              color: accent.withAlpha(225),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF604652),
              //color: Color(0xFFA97155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8C7A5A),
            ),
          ),
        ],
      ),
    ),
  );
}


Widget _buildTimerCard(ThemeData theme, int secondsRemaining) {
  const pastel = Color(0xFFE57373); // your chosen timer color

  // Create tinted glass variants
  final glassBase       = pastel.withValues(alpha: 0.25);   // 25% tint
  final glassHighlight  = pastel.withValues(alpha: 0.40);   // top
  final glassShadow     = pastel.withValues(alpha: 0.18);   // bottom
  final glassBorder     = pastel.withValues(alpha: 0.55);   // border

  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),

          // Main tinted glass color
          color: glassBase,

          // Gradient helps sell the glass look
          gradient: LinearGradient(
            colors: [
              glassHighlight,
              glassShadow,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),

          // Colored border (soft and warm)
          border: Border.all(
            color: glassBorder,
            width: 1.2,
          ),

          // Soft pastel shadow (not dark!)
          boxShadow: [
            BoxShadow(
              color: pastel.withValues(alpha: 0.20),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),

        child: Row(
          children: [
            const Icon(Icons.timer, color: pastel, size: 22),
            const SizedBox(width: 8),

            Text(
              "Session timer",
              style: theme.textTheme.bodyMedium?.copyWith(
                //fontWeight: FontWeight.bold,
                fontFamily: "SuperLobster",
                fontSize: 17,
                color: pastel,
              ),
            ),

            const Spacer(),

            Text(
              _formatTime(secondsRemaining),
              style: const TextStyle(
                //fontWeight: FontWeight.bold,
                fontFamily: "SuperLobster",
                fontSize: 18,
                color: pastel,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



  Widget _buildStatusCard(
    ThemeData theme, {
    required bool checkedIn,
    required String roomLabel,
  }) {
    const borderColor = Color(0xFFF6D7A8);
    const bgChecked = Color(0xFFFFFCF8);
       const bgNotChecked = Color(0xFFFFF4DD);
    const accentText = Color(0xFF3A3024);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: checkedIn ? bgChecked : bgNotChecked,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 14,
      ),
      child: checkedIn
          ? Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  color: Color(0xFFF4A259),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: accentText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "You are currently checked into this room.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8C7A5A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GradientButton(
                  height: 30,
                  borderRadius:
                    BorderRadius.circular(12.0),
                  onPressed: () =>
                      _checkOutRoom(),
                  child: const Text(
                    'Check-out',
                    style: TextStyle(
                      fontFamily: 'SuperLobster',
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF4A259),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You are currently not checked into a room",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: accentText,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFDF9), Color(0xFFFFF3E1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    const Text(
                      "Hello, Student",
                      style: TextStyle(
                        fontFamily: "BrittanySignature",
                        fontSize: 60,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    

                    SizedBox(
                      height: 40,
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: const CursiveDivider(
                        color: Color(0xFFfcbf49),
                        strokeWidth: 6,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // BODY
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 24.0),
                    child: Column(
                      children: [
                        // QUICK ACTIONS CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1D5),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFF6D7A8),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(244, 162, 97, 0.18),
                                offset: Offset(0, 8),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Quick actions",
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: const Color(0xFF604652),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Jump into the tools you use the most.",
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF8C7A5A),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2x2 GRID
                              // 2x2 GRID
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.manage_accounts_rounded,
                                      title: "Account Settings",
                                      subtitle: "Profile & preferences",
                                      accent: const Color(0xFFF08787), 
                                      onTap: () => Navigator.pushNamed(context, '/profile'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.group_rounded,
                                      title: "Find Study Group",
                                      subtitle: "Browse & join groups",
                                      accent: const Color(0xFFEDA35A),
                                      onTap: () => Navigator.pushNamed(context, '/studygroup'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.meeting_room_rounded,
                                      title: "Find Room",
                                      subtitle: "Locate study spaces",
                                      accent: const Color(0xFFA3DC9A), 
                                      onTap: () => Navigator.pushNamed(context, '/rooms'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.event_note_rounded,
                                      title: "My Activities",
                                      subtitle: "Requests & invites",
                                      accent: const Color(0xFF9EC6F3), 
                                      onTap: () => Navigator.pushNamed(context, '/activities'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // TIMER (only when checked in)
                        if (checkedIn)
                          _buildTimerCard(
                            theme,
                            TimerService.instance.secondsRemaining,
                          ),

                        if (checkedIn) const SizedBox(height: 25),

                        // STATUS
                        _buildStatusCard(
                          theme,
                          checkedIn: checkedIn,
                          roomLabel: roomLabel,
                        ),
                      ],
                    ),
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