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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Study Groups",
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: const Divider(
                    color: Colors.black,
                    thickness: 2,
                  ),
                ),

                const SizedBox(height: 10),

                // Expandable group list
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFADA7A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const AllGroups(),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    _futureGroups =
        _service.listAllStudyGroups(); // returns StudyGroupResponses with appropriate access
  }

  void _reloadData() {
    setState(() {
      _futureGroups = _service
          .listAllStudyGroups(); // Re-assign the Future to trigger reload
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: FutureBuilder<List<StudyGroupResponse>>(
        future: _futureGroups,
        builder: (BuildContext context,
            AsyncSnapshot<List<StudyGroupResponse>> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Text(
              'Error: ${snap.error}',
              style: const TextStyle(height: 1.3),
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
      ),
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
  Future<void> _showErrorPopup(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Error',
            style: TextStyle(fontWeight: FontWeight.bold),
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

  String _friendlyErrorMessage(Object e) {
    final text = e.toString();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length);
    }
    return text;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
 @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  return ExpansionPanelList(
    expansionCallback: (int panelIndex, bool isExpanded) {
      setState(() {
        _groups[panelIndex].isExpanded = isExpanded;
      });
    },
    children: _groups.map<ExpansionPanel>((StudyGroupResponse group) {
      return ExpansionPanel(
        canTapOnHeader: true,
        backgroundColor: const Color(0xFFFCF6DB),
        headerBuilder: (BuildContext context, bool isExpanded) {
          return ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: isExpanded ? theme.primaryColor : Colors.black,
                  ),
                ),
                Text(
                  "Owned by: \n${group.ownerDisplayName}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isExpanded ? theme.primaryColor : Colors.black,
                  ),
                ),
                Text(
                  group.ownerHandle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isExpanded
                        ? theme.primaryColor
                        : theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            trailing: SizedBox(
              width: 50,
              child: Text(
                group.date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Location: ${group.buildingCode} - ${group.roomNumber}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Time: ${group.startTime} - ${group.endTime}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Number of members: ${group.quantity}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),

                // -------------------------------
                // PUBLIC VIEW
                // -------------------------------
                if (group.access == "public") ...[
                  Align(
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      ignoring: group.hasPendingRequest,
                      child: Opacity(
                        opacity: group.hasPendingRequest ? 0.5 : 1.0,
                        child: GradientButton(
                          height: 35,
                          borderRadius: BorderRadius.circular(12.0),
                          onPressed: () async {
                            if (group.hasPendingRequest) return;

                            try {
                              debugPrint(
                                "Sending Join Request for group ID: ${group.id}",
                              );
                              await _service.sendJoinRequest(group.id);

                              // immediately mark as pending in UI
                              setState(() {
                                group.hasPendingRequest = true;
                              });

                              if (!mounted) return;
                              await _showErrorPopup(
                                'Join request sent! Once approved, this group will appear under My Study Groups.',
                              );
                            } catch (e) {
                              if (!mounted) return;
                              await _showErrorPopup(
                                'Failed to send join request: ${_friendlyErrorMessage(e)}',
                              );
                            }
                          },
                          child: Text(
                            group.hasPendingRequest
                                ? "Pending"
                                : "Send Join Request",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]

                // -------------------------------
                // OWNER VIEW
                // -------------------------------
                else if (group.access == "owner") ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "You are the owner of this study group.",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Members: ${group.members}",
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]

                // -------------------------------
                // MEMBER VIEW → POPUP
                // -------------------------------
                else if (group.access == "member") ...[
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.info_outline),
                      label: const Text(
                        "View my membership",
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final List<dynamic> membersRaw = group.members ?? [];
                        final membersList = membersRaw.isNotEmpty
                            ? membersRaw.join(', ')
                            : 'No members listed.';

                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text(
                              "Membership Information",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              'You are already part of this study group.\n\nMembers:\n$membersList',
                              style: const TextStyle(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                child: const Text("OK"),
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        isExpanded: group.isExpanded,
      );
    }).toList(),
  );
}
}
