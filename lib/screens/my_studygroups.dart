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
// GROUP PANELS (no ExpansionTile, flat cards like studygroup.dart)
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
                "Unable to send invite.",
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

  void _showInviteDialog(StudyGroupResponse groupResp) {
    _inviteHandleController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFFFFF7EB),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Invite by handle",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inviteHandleController,
                decoration: const InputDecoration(
                  prefixText: '@',
                  hintText: "student123",
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text("Send invite"),
                  onPressed: () async {
                    final handle = _inviteHandleController.text.trim();
                    if (handle.isEmpty) return;

                    try {
                      
                      await _service.inviteByHandle(groupResp.id, handle);
                      if (!mounted) return;

                      // close the sheet + refresh data
                      Navigator.of(ctx).pop();
                      _inviteHandleController.clear();
                      _onReloadNeeded();

                      
                      _showSuccessSnackBar('Invite sent to @$handle');
                    } catch (e) {
                      if (!mounted) return;

                      final String cleaned =
                          e.toString().replaceFirst("Exception: ", "").trim();
                      debugPrint('inviteByHandle error: $cleaned');

                      String userMessage;
                      final lower = cleaned.toLowerCase();

                      if (lower.contains('time overlap')) {
                        userMessage =
                            '\nFor one of the following reason:\n\n-This user already has a study group at that time. \n\n -This user is a member of this study group.';
                      } else if (lower.contains('handle not found') ||
                          lower.contains('user not found') ||
                          lower.contains('no user found') ||
                          lower.contains('unknown handle')) {
                        userMessage =
                            'Unable to send invite.\nThat handle could not be found. Please check the spelling and try again.';
                      } else if (lower.contains('already in this study group') ||
                          lower.contains('already a member of this study group') ||
                          lower.contains('already a member')) {
                       
                        userMessage = 'Already in this study group.';
                      } else {
                        userMessage = 'Unable to send invite.\n$cleaned';
                      }

                      await _showErrorPopup(userMessage);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
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
  }

  // Opens the bottom sheet with Invite / Edit / Delete
  void _showOwnerActionsSheet(StudyGroupResponse groupResp) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFFFFF7EB),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                "Study Group Options",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Divider(indent: 16, endIndent: 16),

              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text("Invite By Handle"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInviteDialog(groupResp);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text("Edit Group"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditConfirmationDialog(context, groupResp);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  "Delete Group",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmationDialog(context, groupResp.id);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget buildRolePill(String role) {
    Color bg;
    Color text;

    switch (role) {
      case "owner":
        bg = const Color(0xFFB5E4C7); // soft green
        text = const Color(0xFF1B5E20);
        break;
      case "member":
        bg = const Color(0xFFBBDEFB); // soft blue
        text = const Color(0xFF0D47A1);
        break;
      default:
        bg = const Color(0xFFE0E0E0);
        text = const Color(0xFF424242);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role[0].toUpperCase() + role.substring(1), // capitalizes
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
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
              maxLength: 60,
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
                        final groupUpdated = groupResp.copyWith(
                            name: _groupNameController.text.trim());
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
  // MAIN BUILD 
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
                color: const Color(0xFFFFF7EB),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: name 
                 Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Text(
        group.name,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    ),
    const SizedBox(width: 8),
    Text(
      formatDate(group.date),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  ],
),




                  const SizedBox(height: 10),

                  // BODY – fetch full group info
                  FutureBuilder<StudyGroupResponse>(
                    future: _service.getStudyGroup(group.id),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            height: 22,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (snap.hasError || !snap.hasData) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Error loading group details',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
final groupResponse = snap.data!;
final bool isOwner = groupResponse.access == "owner";
final bool isMember = groupResponse.access == "member";
final int memberCount = (groupResponse.members?.length ?? 0);

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // 1) OWNER INFO directly under the group name
    Text(
      'Owned by: ${groupResponse.ownerDisplayName}',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    const SizedBox(height: 2),
    Text(
       '@${groupResponse.ownerHandle}',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.black54,
      ),
    ),

    const SizedBox(height: 8),

    // 2) Location + building info + time + members
    FutureBuilder<String?>(
      future: _service.getBuildingName(groupResponse.buildingCode),
      builder: (context, buildingSnap) {
        final buildingName =
            buildingSnap.data ?? groupResponse.buildingCode;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${groupResponse.buildingCode} - ${groupResponse.roomNumber}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    buildingName,
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
                const Icon(
                  Icons.access_time,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${formatTo12Hour(group.startTime)} - ${formatTo12Hour(group.endTime)}',
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
                const Icon(
                  Icons.group_outlined,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Members: $memberCount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),

    // 3) OWNER / MEMBER ACTIONS (unchanged)
    if (isOwner) ...[
      const SizedBox(height: 12),
      const Divider(
        color: Color(0x22000000),
        thickness: 1,
        height: 20,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.group_outlined, size: 18),
              label: const Text(
                "View Members",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFB58A3A)),
                backgroundColor: const Color(0xFFFFF7E0),
                foregroundColor: const Color(0xFF8B6D41),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final membersRaw = groupResponse.members ?? [];
                final memberNames =
                    membersRaw.map((m) => m.toString()).toList();

                await _showMembershipPopup(
                  isOwner: true,
                  ownerName: groupResponse.ownerDisplayName,
                  members: memberNames,
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            color: Colors.brown,
            padding: EdgeInsets.zero,
            onPressed: () => _showOwnerActionsSheet(groupResponse),
            tooltip: "More actions",
          ),
        ],
      ),
    ],

    if (isMember) ...[
      const SizedBox(height: 12),
      const Divider(
        color: Color(0x22000000),
        thickness: 1,
        height: 20,
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.group_outlined, size: 18),
                label: const Text(
                  "View Members",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB58A3A)),
                  backgroundColor: const Color(0xFFFFF7E0),
                  foregroundColor: const Color(0xFF8B6D41),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final membersRaw = groupResponse.members ?? [];
                  final memberNames =
                      membersRaw.map((m) => m.toString()).toList();

                  await _showMembershipPopup(
                    isOwner: false,
                    ownerName: groupResponse.ownerDisplayName,
                    members: memberNames,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => _showLeaveConfirmationDialog(
                  context,
                  groupResponse.id,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color.fromARGB(255, 223, 75, 12),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
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
        );
      },
    );
  }
}
