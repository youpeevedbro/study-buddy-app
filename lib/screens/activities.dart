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

  /// Mixed list of:
  ///  - join requests for groups I OWN  (kind = "joinRequest")
  ///  - group invites that OTHERS sent TO ME (kind = "invite")
  ///
  /// Common keys:
  ///  - "kind": "joinRequest" | "invite"
  ///  - "groupId"
  ///  - "groupName"
  ///  - "userId"        -> other person's uid
  ///  - "userHandle"    -> other person's handle
  ///  - "userName"      -> other person's display name
  ///  - "inviteeId"     -> for invites (so decline knows who the invitee is)
  List<Map<String, dynamic>> incomingRequests = [];

  /// Outgoing join requests *I* have sent (public user → owner).
  List<StudyGroupResponse> outgoingJoinRequests = [];

  /// Outgoing invites that I (as owner) have sent to others.
  /// Each map:
  ///  - "groupId", "groupName"
  ///  - "inviteeId", "inviteeHandle", "inviteeName"
  List<Map<String, dynamic>> outgoingInvites = [];

  // 0 = Incoming, 1 = Outgoing
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadAllRequests();
  }

  // ----------------------------------------------------------
  // Load incoming + outgoing (join requests + invites)
  // ----------------------------------------------------------
  Future<void> _loadAllRequests() async {
    if (!mounted) return;
    try {
      setState(() => _loading = true);

      // 1) All current groups (public/member/owner + hasPendingRequest)
      final userGroups = await _service.listAllStudyGroups();

      // 2) Invites that were sent TO ME
      final myInvites = await _service.listMyIncomingInvites();

      final List<Map<String, dynamic>> incoming = [];
      final List<StudyGroupResponse> outgoingJoin = [];
      final List<Map<String, dynamic>> outgoingInv = [];

      // ---- A. Join requests + outgoing invites for groups I OWN ----
      for (var group in userGroups) {
        // A1) Incoming join requests (other users asking to join my group)
        if (group.access == "owner") {
          final groupRequests = await _service.listIncomingRequests(group.id);
          for (var req in groupRequests) {
            incoming.add({
              "kind": "joinRequest",
              "groupId": group.id,
              "groupName": group.name,
              "userId": req['requesterId'],
              "userHandle": req['requesterHandle'],
              "userName": req['requesterName'],
            });
          }

          // A2) Outgoing invites I (owner) sent to others
          final groupInvites = await _service.listOutgoingInvites(group.id);
          for (var inv in groupInvites) {
            outgoingInv.add({
              "groupId": inv["groupId"],
              "groupName": inv["groupName"],
              "inviteeId": inv["inviteeId"],
              "inviteeHandle": inv["inviteeHandle"],
              "inviteeName": inv["inviteeDisplayName"],
            });
          }
        }

        // B) Outgoing join requests I have sent as a public user
        if (group.hasPendingRequest == true) {
          outgoingJoin.add(group);
        }
      }

      // ---- C. Invites that were sent TO ME (I am the invitee) ----
      for (var inv in myInvites) {
        incoming.add({
          "kind": "invite",
          "groupId": inv["groupId"],
          "groupName": inv["groupName"],
          "userId": inv["ownerId"],          // owner (who invited me)
          "userHandle": inv["ownerHandle"],
          "userName": inv["ownerDisplayName"],
          "inviteeId": inv["inviteeId"],     // me
        });
      }

      if (!mounted) return;
      setState(() {
        incomingRequests = incoming;
        outgoingJoinRequests = outgoingJoin;
        outgoingInvites = outgoingInv;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load requests/invites: $e");
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load requests: $e')),
      );
    }
  }

  // ----------------------------------------------------------
  // Accept / Decline (handles both join requests & invites)
  // ----------------------------------------------------------
  Future<void> acceptRequest(int index) async {
    final request = incomingRequests[index];
    final kind = request["kind"] as String? ?? "joinRequest";
    final groupId = request["groupId"] as String;

    try {
      if (kind == "joinRequest") {
        // Owner accepting someone else's join request
        final requesterId = request["userId"] as String;
        await _service.acceptIncomingRequest(
          groupId: groupId,
          requesterId: requesterId,
        );
      } else if (kind == "invite") {
        // Invitee accepting an owner's invite
        await _service.acceptGroupInvite(groupId);
      }

      setState(() {
        incomingRequests.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request processed')),
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
    final kind = request["kind"] as String? ?? "joinRequest";
    final groupId = request["groupId"] as String;

    try {
      if (kind == "joinRequest") {
        // Owner declining a join request
        final requesterId = request["userId"] as String;
        await _service.declineIncomingRequest(
          groupId: groupId,
          requesterId: requesterId,
        );
      } else if (kind == "invite") {
        // Invitee declining an invite
        final inviteeId = request["inviteeId"] as String;
        await _service.declineOrCancelGroupInvite(groupId, inviteeId);
      }

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
  // Cancel outgoing JOIN request (public → owner)
  // ----------------------------------------------------------
  Future<void> cancelOutgoingJoinRequest(String groupId) async {
    try {
      await _service.cancelMyJoinRequest(groupId);

      setState(() {
        outgoingJoinRequests.removeWhere((g) => g.id == groupId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Join request cancelled")),
      );
    } catch (e) {
      debugPrint("Failed to cancel join request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel request: $e")),
      );
    }
  }

  // ----------------------------------------------------------
  // Cancel/decline outgoing INVITE (owner → invitee)
  // ----------------------------------------------------------
  Future<void> cancelOutgoingInvite(int index) async {
    final inv = outgoingInvites[index];
    final groupId = inv["groupId"] as String;
    final inviteeId = inv["inviteeId"] as String;

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

  Widget _buildIncomingList() {
    return Column(
      key: const ValueKey('incoming'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Swipe right to accept, left to decline.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        incomingRequests.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Text(
                    "No incoming requests or invites",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: incomingRequests.length,
                itemBuilder: (context, index) {
                  final request = incomingRequests[index];
                  final kind = request["kind"] as String? ?? "joinRequest";

                  final userName = request["userName"] ?? "";
                  final groupName = request["groupName"] ?? "";

                  final subtitleText = (kind == "joinRequest")
                      ? "$userName wants to join."
                      : "$userName invited you to join.";

                  return Dismissible(
                    key: ValueKey(
                        '${request["groupId"]}_${request["userId"]}_$index'),
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
                          title: const Text('Decline'),
                          content: Text(
                            'Are you sure you want to decline this?',
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
                                  groupName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitleText,
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
    );
  }

  Widget _buildOutgoingList() {
    return Column(
      key: const ValueKey('outgoing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outgoingInvites.isEmpty && outgoingJoinRequests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                "No outgoing requests or invites",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else ...[
          if (outgoingInvites.isNotEmpty) ...[
            const Text(
              "Invites you've sent",
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
                final inv = outgoingInvites[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
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
                    vertical: 14,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(
                          Icons.outgoing_mail,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv["groupName"] ?? "",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Invited: ${inv["inviteeName"]} (${inv["inviteeHandle"]})",
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
            const SizedBox(height: 16),
          ],
          if (outgoingJoinRequests.isNotEmpty) ...[
            const Text(
              "Join requests you've sent",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: outgoingJoinRequests.length,
              itemBuilder: (context, index) {
                final group = outgoingJoinRequests[index];
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
                            onTap: () => cancelOutgoingJoinRequest(group.id),
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
          ],
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

              // MY STUDY GROUPS BUTTON
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

              // INCOMING / OUTGOING TOGGLE
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
                                  "Incoming (${incomingRequests.length})",
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
                                  "Outgoing (${outgoingInvites.length + outgoingJoinRequests.length})",
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
                        onRefresh: _loadAllRequests,
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
