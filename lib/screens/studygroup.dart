// Study Groups screen
import 'package:flutter/material.dart';
import 'package:study_buddy/models/group.dart';
import '../services/group_service.dart';

import '../components/grad_button.dart';

class StudyGroupsPage extends StatefulWidget {
  const StudyGroupsPage({super.key});

  @override
  State<StudyGroupsPage> createState() => _StudyGroupsPageState();
}

class _StudyGroupsPageState extends State<StudyGroupsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context), // back to Dashboard
        ),
        toolbarHeight: 100,
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFCF8), Color(0xFFFFF0C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Study Groups",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.2,
                    fontFamily: 'SuperLobster',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.only(right: 40),
                  height: 2,
                  color: Colors.black87,
                ),
                const SizedBox(height: 16),

                // List content
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: AllGroups(),
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

class AllGroups extends StatefulWidget {
  const AllGroups({super.key});

  @override
  State<AllGroups> createState() => _AllGroupsState();
}

class _AllGroupsState extends State<AllGroups> {
  final GroupService _service = const GroupService();
  late Future<List<StudyGroupResponse>> _futureGroups;

  @override
  void initState() {
    super.initState();
    _futureGroups = _service.listAllStudyGroups(); // returns StudyGroupResponses with appropriate access
  }

  void _reloadData() {
    setState(() {
      _futureGroups =
          _service.listAllStudyGroups(); // Re-assign the Future to trigger reload
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudyGroupResponse>>(
      future: _futureGroups,
      builder:
          (BuildContext context, AsyncSnapshot<List<StudyGroupResponse>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final groups = snap.data ?? [];

        if (groups.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'There are currently no active study groups.',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return AllGroupPanels(groups: groups, onReloadNeeded: _reloadData);
      },
    );
  }
}

class AllGroupPanels extends StatefulWidget {
  final VoidCallback onReloadNeeded;
  final List<StudyGroupResponse> groups;

  const AllGroupPanels({
    super.key,
    required this.groups,
    required this.onReloadNeeded,
  });

  @override
  State<AllGroupPanels> createState() => _AllGroupPanelsState();
}

class _AllGroupPanelsState extends State<AllGroupPanels> {
  late List<StudyGroupResponse> _groups;
  late VoidCallback _onReloadNeeded;
  final GroupService _service = const GroupService();

  // Single text controller for "invite handle" (simple approach)
  final TextEditingController _inviteHandleController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _groups = widget.groups;
    _onReloadNeeded = widget.onReloadNeeded;
  }

  @override
  void dispose() {
    _inviteHandleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers: popup + friendly error
  // ---------------------------------------------------------------------------
  Future<void> _showPopup({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isError ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _statusLabel(StudyGroupResponse group) {
    if (group.access == "owner") return "Owner";
    if (group.access == "member") return "Member";
    if (group.hasPendingRequest == true) return "Pending";
    return "Public";
  }

  Color _statusColor(StudyGroupResponse group) {
    if (group.access == "owner") {
      return const Color(0xFF81C784); // green
    }
    if (group.access == "member") {
      return const Color(0xFF64B5F6); // blue
    }
    if (group.hasPendingRequest == true) {
      return const Color(0xFFFFB74D); // orange
    }
    return const Color(0xFFB0BEC5); // grey
  }

  // ---------------------------------------------------------------------------
  // Membership info (owner / member) – same behavior, nicer UI
  // ---------------------------------------------------------------------------
  Future<void> _showMembershipDialog({
    required bool isOwner,
    required String ownerName,
    required List<dynamic>? rawMembers,
  }) async {
    final List<String> members =
        (rawMembers ?? []).map((e) => e.toString()).toList();
    final List<String> others =
        members.where((m) => m != ownerName).toList(growable: false);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Membership Information",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOwner
                  ? "You are the owner of this study group."
                  : "You are a member of this study group.",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Owner section
            const Text(
              "Owner:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ownerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Members
            const Text(
              "Members:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (others.isEmpty)
              const Text(
                "No other members.",
                style: TextStyle(
                  color: Colors.black54,
                ),
              )
            else
              ...others.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI: single card builder (functionality SAME as before)
  // ---------------------------------------------------------------------------
  Widget _buildGroupCard(StudyGroupResponse group) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW: name + date + status pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Owned by: ${group.ownerDisplayName}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      group.ownerHandle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    group.date,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(group),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(group),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // INFO ROWS
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${group.buildingCode} - ${group.roomNumber}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 18),
              const SizedBox(width: 6),
              Text(
                "${group.startTime} - ${group.endTime}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                "Members: ${group.quantity}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ACTION AREA – SAME BEHAVIOR AS OLD UI
          if (group.access == "public") ...[
            Align(
              alignment: Alignment.center,
              child: IgnorePointer(
                ignoring: group.hasPendingRequest,
                child: Opacity(
                  opacity: group.hasPendingRequest ? 0.5 : 1.0,
                  child: GradientButton(
                    height: 38,
                    borderRadius: BorderRadius.circular(14.0),
                    onPressed: () async {
                      if (group.hasPendingRequest) return;

                      try {
                        debugPrint(
                          "Sending Join Request for group ID: ${group.id}",
                        );
                        await _service.sendJoinRequest(group.id);

                        setState(() {
                          group.hasPendingRequest = true;
                        });

                        if (!mounted) return;
                        await _showPopup(
                          title: "Notice",
                          message:
                              "Join request sent — please wait for approval.",
                        );
                      } catch (e) {
                        if (!mounted) return;

                        final String cleaned =
                            e.toString().replaceFirst("Exception: ", "").trim();
                        debugPrint('sendJoinRequest error: $cleaned');

                        final lower = cleaned.toLowerCase();
                        String message;

                        if (lower.contains('time overlap')) {
                          message =
                              'You cannot join this study group because its time overlaps with one of your existing study groups.';
                        } else if (lower.contains('cannot invite yourself') ||
                            lower.contains('cannot join your own') ||
                            lower.contains('own study group')) {
                          message =
                              'You cannot send a join request to your own study group.';
                        } else {
                          message = cleaned.isEmpty
                              ? 'Something went wrong while sending your join request.'
                              : cleaned;
                        }

                        await _showPopup(
                          title: "Error",
                          message: message,
                          isError: true,
                        );
                      }
                    },
                    child: Text(
                      group.hasPendingRequest ? "Pending" : "Send Join Request",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (group.access == "owner" || group.access == "member") ...[
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group_outlined, size: 18),
                label: const Text(
                  "View Members",
                  style: TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4E8C2),
                  foregroundColor: Colors.brown,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () async {
                  await _showMembershipDialog(
                    isOwner: group.access == "owner",
                    ownerName: group.ownerDisplayName,
                    rawMembers: group.members,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build grouped list (sections) – functionality unchanged
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Split groups into sections
    final yourGroups = _groups
        .where((g) => g.access == "owner" || g.access == "member")
        .toList();
    final pendingGroups = _groups
        .where((g) =>
            g.access != "owner" &&
            g.access != "member" &&
            g.hasPendingRequest == true)
        .toList();
    final discoverGroups = _groups
        .where((g) =>
            g.access == "public" &&
            (g.hasPendingRequest != true)) // only truly joinable
        .toList();

    // Sort each section by date (string compare is ok if format is YYYY-MM-DD)
    int dateCompare(StudyGroupResponse a, StudyGroupResponse b) =>
        a.date.compareTo(b.date);

    yourGroups.sort(dateCompare);
    pendingGroups.sort(dateCompare);
    discoverGroups.sort(dateCompare);

    final List<Widget> children = [];

    void addSection(String title, List<StudyGroupResponse> list) {
      if (list.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 4));
      children.addAll(list.map(_buildGroupCard));
      children.add(const SizedBox(height: 12));
    }

    addSection("Your Groups", yourGroups);
    addSection("Pending Requests", pendingGroups);
    addSection("Discover Groups", discoverGroups);

    if (children.isEmpty) {
      // Fallback (should not really happen because groups.isNotEmpty)
      children.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              "No study groups to display.",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
