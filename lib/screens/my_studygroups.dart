import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/grad_button.dart';
import 'addgroup2.dart';
import '../models/group.dart';
import '../services/group_service.dart';

class MyStudyGroupsPage extends StatefulWidget {
  const MyStudyGroupsPage({super.key});

  @override
  State<MyStudyGroupsPage> createState() => _MyStudyGroupsPageState();
}

class _MyStudyGroupsPageState extends State<MyStudyGroupsPage> {
  Key _key = UniqueKey(); // forces Groups to rebuild

  void rebuildGroups() {
    setState(() {
      _key = UniqueKey();
    });
  }

  void _navigateToAddGroup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddGroupPage()),
    );
    rebuildGroups();
  }

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
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: 100,
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      body: Container(
        // soft gradient like My Activities
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFCF8), Color(0xFFFFF0C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "My Study Groups",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.2,
                    fontFamily: 'SuperLobster',
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  height: 2,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Add Study Group button – pill gradient
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GradientButton(
                  borderRadius: BorderRadius.circular(14),
                  height: 44,
                  onPressed: _navigateToAddGroup,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "Add Study Group",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Groups list
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Groups(key: _key),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GROUPS FUTURE WRAPPER
// ---------------------------------------------------------------------------

class Groups extends StatefulWidget {
  const Groups({super.key});

  @override
  State<Groups> createState() => _GroupsState();
}

class _GroupsState extends State<Groups> {
  final GroupService _service = const GroupService();
  late Future<List<JoinedGroup>> _futureGroups;

  @override
  void initState() {
    super.initState();
    _futureGroups = _service.listMyStudyGroups();
  }

  void _reloadData() {
    setState(() {
      _futureGroups = _service.listMyStudyGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JoinedGroup>>(
      future: _futureGroups,
      builder: (BuildContext context, AsyncSnapshot<List<JoinedGroup>> snap) {
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
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        final groups = snap.data ?? [];

        if (groups.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'You have no current Study Groups.',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return GroupPanels(
          groups: groups,
          onReloadNeeded: _reloadData,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// GROUP PANELS
// ---------------------------------------------------------------------------

class GroupPanels extends StatefulWidget {
  final VoidCallback onReloadNeeded;
  final List<JoinedGroup> groups;

  const GroupPanels(
      {super.key, required this.groups, required this.onReloadNeeded});

  @override
  State<GroupPanels> createState() => _GroupPanelsState();
}

class _GroupPanelsState extends State<GroupPanels> {
  bool _isDeleting = false;
  bool _isLeaving = false;
  bool _isEditing = false;

  late List<JoinedGroup> _groups;
  late VoidCallback _onReloadNeeded;
  final GroupService _service = const GroupService();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();
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
    _groupNameController.dispose();
    _inviteHandleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // POPUPS + FORMAT HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _showErrorPopup(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(
                Icons.error_outline,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Text(
                "Error",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
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
              child: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessPopup(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
              SizedBox(width: 8),
              Text(
                "Success",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
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
              child: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  String formatTo12Hour(String time24h) {
    try {
      final parsed = DateTime.parse("2020-01-01 $time24h:00");
      return DateFormat("h:mm a").format(parsed);
    } catch (_) {
      return time24h;
    }
  }

  String formatDate(String yyyymmdd) {
    try {
      final parsed = DateTime.parse(yyyymmdd);
      return DateFormat("MMM d, yyyy").format(parsed);
    } catch (_) {
      return yyyymmdd;
    }
  }

  Future<void> _showMembershipPopup({
    required bool isOwner,
    required String ownerName,
    required List<String> members,
  }) async {
    final List<String> others = members.where((m) => m != ownerName).toList();
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
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
              ),
              const SizedBox(height: 16),
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
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...others.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.grey),
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
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE / LEAVE / EDIT LOGIC (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, String groupID) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              const Text('Are you sure you want to delete this Study Group?'),
          content: const Text(
              'This Study Group will be permanently deleted and all members will be disbanded.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: _isDeleting ? null : () => _handleDelete(groupID),
              child: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDelete(String groupID) async {
  setState(() => _isDeleting = true);

  try {
    await _service.deleteStudyGroup(groupID);
    _onReloadNeeded();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Study Group successfully deleted',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF81C784), // <-- THEME COLOR
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        duration: const Duration(seconds: 2),
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (mounted) {
      await _showErrorPopup('Failed to delete study group: $e');
    }
  } finally {
    if (mounted) setState(() => _isDeleting = false);
  }
}


  Future<void> _showLeaveConfirmationDialog(
      BuildContext context, String groupID) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              const Text('Are you sure you want to leave this Study Group?'),
          content: const Text(
              'After leaving, you will have to send another request if you wish to rejoin this group.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: _isLeaving ? null : () => _handleLeaving(groupID),
              child: _isLeaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Leave"),
            ),
          ],
        );
      },
    );
  }

Future<void> _handleLeaving(String groupID) async {
  setState(() => _isLeaving = true);

  try {
    await _service.leaveStudyGroup(groupID);
    _onReloadNeeded();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Successfully left Study Group',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF81C784), // SAME THEME COLOR
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        duration: const Duration(seconds: 2),
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (mounted) {
      await _showErrorPopup('Failed to leave study group: $e');
    }
  } finally {
    if (mounted) setState(() => _isLeaving = false);
  }
}


  Future<void> _showEditConfirmationDialog(
      BuildContext context, StudyGroupResponse groupResp) async {
    _groupNameController.text = groupResp.name;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Editing Study Group: \n${groupResp.name}"),
          contentPadding: const EdgeInsets.fromLTRB(22, 44.0, 22, 20.0),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Study Group name..',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: _isEditing
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        final groupUpdated =
                            groupResp.copyWith(name: _groupNameController.text
                                .trim());
                        _handleUpdate(groupUpdated);
                      }
                    },
              child: _isEditing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUpdate(StudyGroupResponse groupUpdated) async {
  setState(() => _isEditing = true);

  try {
    await _service.updateStudyGroup(groupUpdated);
    _onReloadNeeded();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Successfully updated Study Group',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF81C784), // same theme color
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        duration: Duration(seconds: 2),
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (mounted) {
      await _showErrorPopup('Failed to update study group: $e');
    }
  } finally {
    if (mounted) setState(() => _isEditing = false);
  }
}


  // ---------------------------------------------------------------------------
  // MAIN BUILD – CARD + EXPANSIONTILE
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      physics: const BouncingScrollPhysics(),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Card(
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFEF6EC),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 16,
                    spreadRadius: 1, 
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: group.isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      group.isExpanded = expanded;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),

                  // ===== HEADER =====
                  title: Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDate(group.date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatTo12Hour(group.startTime)} - ${formatTo12Hour(group.endTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),

                  // ===== BODY =====
                  children: [
                    FutureBuilder(
                      future: _service.getStudyGroup(group.id),
                      builder: (context, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              '${snap.error}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        final groupResponse = snap.data!;
                        final bool isOwner =
                            groupResponse.access == "owner";
                        final bool isMember =
                            groupResponse.access == "member";

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),

                            // Building name lookup
                            FutureBuilder(
                              future: _service
                                  .getBuildingName(groupResponse.buildingCode),
                              builder: (context, buildingSnap) {
                                if (buildingSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text("Location: ...");
                                }

                                final buildingName =
                                    buildingSnap.data ??
                                        groupResponse.buildingCode;

                                return Text(
                                  "Location: $buildingName - ${groupResponse.roomNumber}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 6),
                            Text(
                              "Owner: ${groupResponse.ownerDisplayName} (${groupResponse.ownerHandle})",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ===== OWNER VIEW =====
                            if (isOwner) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.group_outlined,
                                      size: 18),
                                  label: const Text("View Members"),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final membersRaw =
                                        groupResponse.members ?? [];
                                    final memberNames = membersRaw
                                        .map((m) => m.toString())
                                        .toList();

                                    await _showMembershipPopup(
                                      isOwner: true,
                                      ownerName:
                                          groupResponse.ownerDisplayName,
                                      members: memberNames,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Invite by handle",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _inviteHandleController,
                                      decoration: const InputDecoration(
                                        prefixText: '@',
                                        hintText: "student123",
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final handle =
                                          _inviteHandleController.text
                                              .trim();
                                      if (handle.isEmpty) return;

                                      try {
                                        await _service.inviteByHandle(
                                            groupResponse.id, handle);
                                        if (!mounted) return;

                                        await _showSuccessPopup(
                                          'Invite sent to @$handle.\nPlease wait for approval.',
                                        );

                                        _inviteHandleController.clear();
                                        _onReloadNeeded();
                                      } catch (e) {
                                        if (!mounted) return;

                                        final String cleaned = e
                                            .toString()
                                            .replaceFirst(
                                                "Exception: ", "")
                                            .trim();
                                        debugPrint(
                                            'inviteByHandle error: $cleaned');

                                        String userMessage;
                                        final lower =
                                            cleaned.toLowerCase();

                                        if (lower
                                            .contains('time overlap')) {
                                          userMessage =
                                              'Unable to send invite.\nThis user already has a study group at that time.';
                                        } else if (lower.contains(
                                                'handle not found') ||
                                            lower.contains(
                                                'user not found') ||
                                            lower.contains(
                                                'no user found') ||
                                            lower.contains(
                                                'unknown handle')) {
                                          userMessage =
                                              'Unable to send invite.\nThat handle could not be found. Please check the spelling and try again.';
                                        } else {
                                          userMessage =
                                              'Unable to send invite.\n$cleaned';
                                        }

                                        await _showErrorPopup(
                                            userMessage);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Text("Invite"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    // EDIT – soft beige, brown text, outlined
    SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () => _showEditConfirmationDialog(context, groupResponse),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFB58A3A)), // warm brown
          backgroundColor: const Color(0xFFFFF7E0),          // soft cream
          foregroundColor: const Color(0xFF8B6D41),          // brown text
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          "Edit",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),

    const SizedBox(width: 12),
// DELETE – still stands out, but softer & rounded
    SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () =>
            _showDeleteConfirmationDialog(context, groupResponse.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE35B5B),          // softer red
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: const Text(
          "DELETE",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  ],
),
],

                            // ===== MEMBER VIEW =====
                            if (isMember) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.group_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "View Members",
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFF4E8C2),
                                      foregroundColor: Colors.brown,
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () async {
                                      final membersRaw =
                                          groupResponse.members ?? [];
                                      final memberNames = membersRaw
                                          .map((m) => m.toString())
                                          .toList();

                                      await _showMembershipPopup(
                                        isOwner: false,
                                        ownerName: groupResponse
                                            .ownerDisplayName,
                                        members: memberNames,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),

         SizedBox(
        height: 40,
        child: ElevatedButton(
          onPressed: () => _showLeaveConfirmationDialog(
            context,
            groupResponse.id,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE35B5B),   // same soft red
            foregroundColor: Colors.white,              // white text
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),   // same radius
            ),
            elevation: 3,                                 // same elevation
          ),
          child: const Text(
            "LEAVE",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    
  
],
                                
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
