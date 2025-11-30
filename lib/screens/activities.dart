// lib/pages/myactivities.dart
import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../models/group.dart';


class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({super.key});

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage> {
  final GroupService _service = const GroupService();

  bool _loading = true;

  // JOIN REQUESTS
  List<Map<String, dynamic>> incomingRequests = []; // people requesting to join my groups
  List<StudyGroupResponse> outgoingRequests = [];   // groups I requested to join

  // INVITES
  List<Map<String, dynamic>> incomingInvites = [];  // owners invited ME
  List<Map<String, dynamic>> outgoingInvites = [];  // I (as owner) invited others

  // 0 = Incoming, 1 = Outgoing
  int _selectedTab = 0;


  @override
  void initState() {
    super.initState();
    _loadAllActivities();

  }

  Future<void> _loadAllActivities() async {
    if (!mounted) return;
    try {
      setState(() => _loading = true);

      // 1) Load all groups (used for join requests + outgoing invites as owner)
      final userGroups = await _service.listAllStudyGroups();

      final List<Map<String, dynamic>> joinRequests = [];
      final List<StudyGroupResponse> outgoingJoinRequests = [];
      final List<Map<String, dynamic>> ownerInvites = [];

      for (var group in userGroups) {
        // Incoming join requests: groups where I am the owner
        if (group.access == "owner") {
          final groupRequests =
              await _service.listIncomingRequests(group.id); // join requests
          for (var req in groupRequests) {
            joinRequests.add({
              "groupId": group.id,
              "groupName": group.name,
              "requesterId": req["requesterId"],
              "requesterHandle": req["requesterHandle"],
              "requesterName": req["requesterName"],
            });
          }

          // Outgoing invites: invites I sent as owner
          final invitesForGroup =
              await _service.listOutgoingInvites(group.id); // invites by owner
          for (var inv in invitesForGroup) {
            ownerInvites.add(inv);
          }
        }

        // Outgoing join requests: groups where I have a pending join request
        if (group.hasPendingRequest == true) {
          outgoingJoinRequests.add(group);
        }
      }

      // 2) Incoming invites: people who invited ME to their groups
      final myInvites = await _service.listMyIncomingInvites();

      if (!mounted) return;
      setState(() {
        incomingRequests = joinRequests;
        outgoingRequests = outgoingJoinRequests;
        incomingInvites = myInvites;
        outgoingInvites = ownerInvites;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load activities: $e");
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load activities: $e')),
      );
    }
  }

  // ----------------------------------------------------------
  // Accept / Decline JOIN REQUESTS (people wanting my groups)
  // ----------------------------------------------------------
  Future<void> acceptRequest(int index) async {
    final request = incomingRequests[index];

    try {
      await _service.acceptIncomingRequest(
        groupId: request["groupId"],
        requesterId: request["requesterId"],
      );

      setState(() {
        incomingRequests.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted')),
      );
    } catch (e) {
      debugPrint("Failed to accept request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  Future<void> declineRequest(int index) async {
    final request = incomingRequests[index];

    try {
      await _service.declineIncomingRequest(
        groupId: request["groupId"],
        requesterId: request["requesterId"],
      );

      setState(() {
        incomingRequests.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined')),
      );
    } catch (e) {
      debugPrint("Failed to decline request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline request: $e')),
      );
    }
  }

  // ----------------------------------------------------------
  // Cancel outgoing JOIN requests (I requested to join)
  // ----------------------------------------------------------
  Future<void> cancelOutgoingRequest(String groupId) async {
    try {
      await _service.cancelMyJoinRequest(groupId);

      setState(() {
        outgoingRequests.removeWhere((g) => g.id == groupId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request cancelled")),
      );
    } catch (e) {
      debugPrint("Failed to cancel request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel request: $e")),
      );
    }
  }

  // ----------------------------------------------------------
  // Accept / Decline INVITES sent TO ME
  // ----------------------------------------------------------
  Future<void> acceptInvite(int index) async {
    final invite = incomingInvites[index];
    final groupId = invite["groupId"] as String;

    try {
      await _service.acceptGroupInvite(groupId);

      setState(() {
        incomingInvites.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invite accepted")),
      );
    } catch (e) {
      debugPrint("Failed to accept invite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to accept invite: $e")),
      );
    }
  }

  Future<void> declineInvite(int index) async {
    final invite = incomingInvites[index];
    final groupId = invite["groupId"] as String;
    final inviteeId = invite["inviteeId"] as String;

    try {
      await _service.declineOrCancelGroupInvite(groupId, inviteeId);

      setState(() {
        incomingInvites.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invite declined")),
      );
    } catch (e) {
      debugPrint("Failed to decline invite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to decline invite: $e")),
      );
    }
  }

  // ----------------------------------------------------------
  // Cancel INVITES I sent as owner
  // ----------------------------------------------------------
  Future<void> cancelOutgoingInvite(int index) async {
    final invite = outgoingInvites[index];
    final groupId = invite["groupId"] as String;
    final inviteeId = invite["inviteeId"] as String;

    try {
      await _service.declineOrCancelGroupInvite(groupId, inviteeId);

      setState(() {
        outgoingInvites.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invite cancelled")),
      );
    } catch (e) {
      debugPrint("Failed to cancel invite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel invite: $e")),
      );
    }
  }

  // ----------------------------------------------------------
  // UI helpers
  // ----------------------------------------------------------
  LinearGradient get _brandGradient => const LinearGradient(
        colors: [
          Color(0xFFFFDE59),
          Color(0xFFFF914D),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  // Incoming tab: invites TO me + join requests for my groups
  Widget _buildIncomingList() {
    return Column(
      key: const ValueKey('incoming'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (incomingInvites.isEmpty && incomingRequests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                "No incoming activity",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

        if (incomingInvites.isNotEmpty) ...[
          const Text(
            'Invitations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: incomingInvites.length,
            itemBuilder: (context, index) {
              final invite = incomingInvites[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(
                        Icons.mail_outline,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite["groupName"] ?? "",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${invite["ownerDisplayName"]} (@${invite["ownerHandle"]}) invited you to join.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => acceptInvite(index),
                          tooltip: 'Accept',
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => declineInvite(index),
                          tooltip: 'Decline',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        if (incomingRequests.isNotEmpty) ...[
          const Text(
            'Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Swipe right to accept, left to decline.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: incomingRequests.length,
            itemBuilder: (context, index) {
              final request = incomingRequests[index];
              return Dismissible(
                key: ValueKey(
                    '${request["groupId"]}_${request["requesterId"]}_$index'),
                direction: DismissDirection.horizontal,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Row(
                    children: [
                      Icon(Icons.check, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                secondaryBackground: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.close, color: Colors.white),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await acceptRequest(index);
                    return true;
                  }

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Decline Request'),
                      content: Text(
                        'Are you sure you want to decline this request from ${request["requesterName"]}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await declineRequest(index);
                    return true;
                  }
                  return false;
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(
                          Icons.person_add_alt_1,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request["groupName"] ?? "",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${request["requesterName"]} wants to join.",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "← Swipe →",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // Outgoing tab: my join requests + invites I sent as owner
  Widget _buildOutgoingList() {
    return Column(
      key: const ValueKey('outgoing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outgoingRequests.isEmpty && outgoingInvites.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                "No outgoing activity",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

        if (outgoingRequests.isNotEmpty) ...[
          const Text(
            'Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: outgoingRequests.length,
            itemBuilder: (context, index) {
              final group = outgoingRequests[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(
                        Icons.schedule,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Owner: ${group.ownerDisplayName}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${group.date} • ${group.startTime} - ${group.endTime}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Status: Pending",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => cancelOutgoingRequest(group.id),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: _brandGradient,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        if (outgoingInvites.isNotEmpty) ...[
          const Text(
            'Invitations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: outgoingInvites.length,
            itemBuilder: (context, index) {
              final invite = outgoingInvites[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(
                        Icons.send,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite["groupName"] ?? "",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Invited: ${invite["inviteeDisplayName"]} (@${invite["inviteeHandle"]})",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => cancelOutgoingInvite(index),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: _brandGradient,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final incomingCount = incomingRequests.length + incomingInvites.length;
    final outgoingCount = outgoingRequests.length + outgoingInvites.length;

    return Scaffold(
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
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "My Activities",
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Divider(thickness: 1.5, color: Colors.black),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/mystudygroups'),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "My Study Groups",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: _selectedTab == 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        height: 44,
                        width: MediaQuery.of(context).size.width / 2 - 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E0),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: () {
                              setState(() => _selectedTab = 0);
                            },
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: Text(
                                  "Incoming ($incomingCount)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _selectedTab == 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedTab == 0
                                        ? Colors.orange
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: () {
                              setState(() => _selectedTab = 1);
                            },
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: Text(
                                  "Outgoing ($outgoingCount)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _selectedTab == 1
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedTab == 1
                                        ? Colors.orange
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadAllActivities,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: _selectedTab == 0
                                ? _buildIncomingList()
                                : _buildOutgoingList(),
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
