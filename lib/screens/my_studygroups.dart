import 'package:flutter/material.dart';
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
  Key _key = UniqueKey(); // initial key

  void rebuildGroups() {
    setState(() {
      _key = UniqueKey(); // assign a new key to rebuild
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
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "My Study Groups",
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
              child: const Divider(color: Colors.black, thickness: 2),
            ),
            const SizedBox(height: 10),

            // Add button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GradientButton(
                    onPressed: _navigateToAddGroup,
                    borderRadius: BorderRadius.circular(12),
                    child: const Text(
                      "Add",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

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
                  child: Groups(key: _key),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      _futureGroups =
          _service.listMyStudyGroups(); // Re-assign the Future to trigger reload
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: FutureBuilder<List<JoinedGroup>>(
          future: _futureGroups,
          builder:
              (BuildContext context, AsyncSnapshot<List<JoinedGroup>> snap) {
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
                    child: Text('You have no current Study Groups.',
                        style: TextStyle(fontSize: 18))),
              );
            }

            return GroupPanels(groups: groups, onReloadNeeded: _reloadData);
          }),
    );
  }
}

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

  late List<JoinedGroup> _groups; // only info from joinedStudyGroups
  late VoidCallback _onReloadNeeded;
  final GroupService _service = const GroupService();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();

  // controller for invite handle
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
  //  popup messages (error) + helper for dialog
  // ---------------------------------------------------------------------------
  Future<void> _showErrorPopup(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF4E9D8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Ok"),
            ),
          ],
        );
      },
    );
  }

Widget _buildMembersList(List<dynamic>? rawMembers) {
  final List<String> members =
      (rawMembers ?? []).map((e) => e.toString()).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        "Members",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      if (members.isEmpty)
        const Text(
          "No other members yet.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        )
      else
        ...members.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("•  ", style: TextStyle(fontSize: 14)),
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
  );
}

Future<void> _showMembershipPopup({
  required bool isOwner,
  required String ownerName,
  required List<String> members,
}) async {
  final List<String> others =
      members.where((m) => m != ownerName).toList();
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

            // Owner Section
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

            // Members Section
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
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
                onPressed: _isDeleting
                    ? null
                    : () {
                        _handleDelete(groupID);
                      },
                child: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Delete")),
          ],
        );
      },
    );
  }

  Future<void> _handleDelete(String groupID) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await _service.deleteStudyGroup(groupID);
      _onReloadNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study Group successfully deleted')),
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
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
                onPressed: _isLeaving
                    ? null
                    : () {
                        _handleLeaving(groupID);
                      },
                child: _isLeaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Leave")),
          ],
        );
      },
    );
  }

  Future<void> _handleLeaving(String groupID) async {
    setState(() {
      _isLeaving = true;
    });

    try {
      await _service.leaveStudyGroup(groupID);
      _onReloadNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully left Study Group')),
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
    _groupNameController.text = groupResp.name; // optional: prefill
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
                        borderRadius: BorderRadius.circular(16))),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                }),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
                onPressed: _isEditing
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          StudyGroupResponse groupUpdated =
                              groupResp.copyWith(
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
                    : const Text("Submit")),
          ],
        );
      },
    );
  }

  Future<void> _handleUpdate(StudyGroupResponse groupUpdated) async {
    setState(() {
      _isEditing = true;
    });

    try {
      await _service.updateStudyGroup(groupUpdated);
      _onReloadNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully updated Study Group')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionPanelList(
      expansionCallback: (int panelIndex, bool isExpanded) {
        setState(() {
          _groups[panelIndex].isExpanded = isExpanded;
        });
      },
      children: _groups.map<ExpansionPanel>((JoinedGroup group) {
        return ExpansionPanel(
          canTapOnHeader: true,
          backgroundColor: const Color(0xFFFCF6DB),
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
                title: Text(group.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isExpanded ? theme.primaryColor : Colors.black,
                    )),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(group.date,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${group.startTime} - ${group.endTime}')
                  ],
                ));
          },
          body: group.isExpanded
              ? FutureBuilder(
                  future: _service.getStudyGroup(group.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          '${snap.error}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      );
                    }

                    final groupResponse = snap.data!;
                    return Padding(
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
                                "Location: ${groupResponse.buildingCode} - ${groupResponse.roomNumber}",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                                "Owner: ${groupResponse.ownerDisplayName} (${groupResponse.ownerHandle})",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
  icon: const Icon(Icons.group_outlined),
  label: const Text("View Members"),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
onPressed: () async {
    final List membersRaw = groupResponse.members ?? [];
    final memberNames = membersRaw.map((m) => m.toString()).toList();

    await _showMembershipPopup(
      isOwner: groupResponse.access == "owner",
      ownerName: groupResponse.ownerDisplayName,
      members: memberNames,
    );
  },
),

const SizedBox(height: 8),


                            // OWNER VIEW – add "Invite by handle" here
                            if (groupResponse.access == "owner") ...[
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
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final handle = _inviteHandleController
                                          .text
                                          .trim();
                                      if (handle.isEmpty) return;

                                      try {
                                        await _service.inviteByHandle(
                                            groupResponse.id, handle);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Invited @$handle to this group'),
                                          ),
                                        );
                                        _inviteHandleController.clear();
                                        _onReloadNeeded();
} catch (e) {
  if (!mounted) return;

  // Clean the backend error (remove "Exception:" if present)
  final String cleaned =
      e.toString().replaceFirst("Exception: ", "").trim();

await _showErrorPopup(
  'Unable to send invite.\nThis user already has a study group at that time.',
);

}

                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Text("Invite"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Existing Edit / Delete buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () =>
                                        _showEditConfirmationDialog(
                                            context, groupResponse),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme
                                            .surfaceContainerHighest,
                                        foregroundColor:
                                            theme.colorScheme.onSurfaceVariant,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        maximumSize: const Size(140, 60)),
                                    child: const Text(
                                      "Edit",
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _showDeleteConfirmationDialog(
                                            context, groupResponse.id),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        foregroundColor:
                                            theme.colorScheme.onError,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        maximumSize: const Size(140, 60)),
                                    child: const Text(
                                      "DELETE",
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
if (groupResponse.access == "member") ...[
  const SizedBox(height: 12),

  // MEMBERSHIP INFORMATION BUTTON
  Align(
    alignment: Alignment.centerLeft,
    child: ElevatedButton.icon(
      icon: const Icon(Icons.info_outline),
      label: const Text(
        "Membership Information",
        style: TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey.shade50,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: () async {
        final List membersRaw = groupResponse.members ?? [];
        final memberNames = membersRaw.map((m) => m.toString()).toList();

        await _showMembershipPopup(
          isOwner: false,
          ownerName: groupResponse.ownerDisplayName,
        	members: memberNames,
        );
      },
    ),
  ),

  const SizedBox(height: 12),

  // existing members list under the button
  _buildMembersList(groupResponse.members),

  const SizedBox(height: 16),

  // LEAVE button
  Align(
    alignment: Alignment.bottomRight,
    child: ElevatedButton(
      onPressed: () =>
          _showLeaveConfirmationDialog(context, groupResponse.id),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        maximumSize: const Size(140, 60),
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


                          ],
                        ),
                      ),
                    );
                  })
              : Container(),
          isExpanded: group.isExpanded,
        );
      }).toList(),
    );
  }
}
