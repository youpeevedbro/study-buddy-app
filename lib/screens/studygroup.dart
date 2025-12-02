// lib/pages/studygroups.dart
import 'package:flutter/material.dart';
import 'package:study_buddy/models/group.dart';
import '../services/group_service.dart';
import '../components/grad_button.dart';
import 'package:intl/intl.dart';   

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

// ---------------------------------------------------------------------------
// FUTURE WRAPPER
// ---------------------------------------------------------------------------

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
    _futureGroups = _service.listAllStudyGroups();
  }

  void _reloadData() {
    setState(() {
      _futureGroups = _service.listAllStudyGroups();
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

        return AllGroupPanels(
          groups: groups,
          onReloadNeeded: _reloadData,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// GROUP PANELS – MODERN CARDS + COLLAPSIBLE SECTIONS
// ---------------------------------------------------------------------------

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
  final GroupService _service = GroupService();

  //Format time and date
  String _formatDate(String yyyymmdd) {
    try {
      final d = DateTime.parse(yyyymmdd);
      return DateFormat('MMM d, yyyy').format(d); 
    } catch (_) {
      return yyyymmdd;
    }
  }

  String _formatTime(String hhmm) {
    try {
      // Input is “17:30” → convert to a DateTime and format
      final dt = DateTime.parse("2025-01-01 $hhmm:00");
      return DateFormat('h:mm a').format(dt); 
    } catch (_) {
      return hhmm;
    }
  }

  // Section expansion states
  bool _pendingExpanded = true;
  bool _discoverExpanded = true;

  @override
  void initState() {
    super.initState();
    _groups = widget.groups;
    _onReloadNeeded = widget.onReloadNeeded;
  }

  // ---------------------------------------------------------------------------
  // Helpers: popup + status label/colors
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
    return "Joinable";
  }

  Color _statusColor(StudyGroupResponse group) {
    if (group.access == "member") {
      return const Color(0xFF64B5F6); // blue
    }
    if (group.hasPendingRequest == true) {
      return const Color(0xFFFFB74D); // orange
    }
    return const Color(0xFF81C784); // green
  }

  // ---------------------------------------------------------------------------
  // Membership info dialog (owner / member)
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

            // Owner
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

  // Small helper so all rows look identical and spacing stays consistent
  Widget _buildInfoRow(
    IconData icon,
    String text, {
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Single group card (modern UI, same behavior)
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
          // HEADER: name + owner + date + status pill
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
                      '@${group.ownerHandle}',
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
                    _formatDate(group.date),
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

          // INFO ROWS – now evenly spaced
          Builder(
            builder: (context) {
              const double rowGap = 6.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    "${group.buildingCode} - ${group.roomNumber}",
                  ),
                  const SizedBox(height: rowGap),

                  FutureBuilder<String?>(
                    future: _service.getBuildingName(group.buildingCode),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        // No text while loading; keeps layout clean
                        return const SizedBox.shrink();
                      }

                      final buildingName = snap.data ?? group.buildingCode;

                      return _buildInfoRow(
                        Icons.apartment_rounded,
                        buildingName,
                        fontWeight: FontWeight.w600,
                      );
                    },
                  ),
                  const SizedBox(height: rowGap),

                  _buildInfoRow(
                    Icons.access_time,
                    "${_formatTime(group.startTime)} - ${_formatTime(group.endTime)}",
                  ),
                  const SizedBox(height: rowGap),

                  _buildInfoRow(
                    Icons.group_outlined,
                    "Members: ${group.quantity}",
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // ACTIONS – same logic as old UI
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
                        ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF81C784), // same green as screenshot
    margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    content: const Text(
      "Join request sent — please wait for approval.",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    duration: Duration(seconds: 2),
  ),
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
  // Collapsible section wrapper
  // ---------------------------------------------------------------------------

  Widget _buildCollapsibleSection({
  required String title,
  required List<StudyGroupResponse> groups,
  required bool isExpanded,
  required VoidCallback onHeaderTap,
  bool alwaysShowHeader = false,
}) {
  if (!alwaysShowHeader && groups.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        onTap: onHeaderTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
      AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text(
                  "No groups to discover yet.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
             ),

            // Normal cards when groups exist
            if (groups.isNotEmpty)
              ...groups.map(_buildGroupCard).toList(),

            const SizedBox(height: 8),
          ],
        ),
        crossFadeState:
            isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 200),
      ),
    ],
  );
}


  // ---------------------------------------------------------------------------
  // Build – compute sections + use collapsible sections
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // split into sections
    final discoverGroups = _groups
        .where((g) =>
            g.access == "public" &&
            (g.hasPendingRequest != true))
        .toList();
    final pendingGroups = _groups
        .where((g) =>
            g.access != "owner" &&
            g.access != "member" &&
            g.hasPendingRequest == true)
        .toList();

    int dateCompare(StudyGroupResponse a, StudyGroupResponse b) =>
        a.date.compareTo(b.date);

    pendingGroups.sort(dateCompare);
    discoverGroups.sort(dateCompare);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCollapsibleSection(
            title: "Discover Groups",
            groups: discoverGroups,
            isExpanded: _discoverExpanded,
            onHeaderTap: () {
              setState(() {
                _discoverExpanded = !_discoverExpanded;
              });
            },
            alwaysShowHeader: true,
          ),
          _buildCollapsibleSection(
            title: "Pending Requests",
            groups: pendingGroups,
            isExpanded: _pendingExpanded,
            onHeaderTap: () {
              setState(() {
                _pendingExpanded = !_pendingExpanded;
              });
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
