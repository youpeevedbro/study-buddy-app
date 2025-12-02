// lib/pages/myactivities.dart
import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../models/group.dart';
import 'package:intl/intl.dart';

class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({super.key});

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage> {
  final GroupService _service = const GroupService();

  bool _loading = true;

  // Incoming:
  //  - join requests for groups I own
  //  - invites sent TO me
  //
  // Each map has:
  //  kind: "joinRequest" | "invite"
  //  groupId, groupName
  //  userId, userName, userHandle  (requester or owner)
  //  inviteeId (only for invites; the invited user, normally me)
  List<Map<String, dynamic>> incomingRequests = [];

  // Outgoing:
  //  - join requests I have sent (StudyGroupResponse with hasPendingRequest == true)
  //  - invites I have sent as owner
  List<StudyGroupResponse> outgoingRequests = [];
  List<Map<String, dynamic>> outgoingInvites = [];

  // 0 = Incoming, 1 = Outgoing
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  LinearGradient get _brandGradient => const LinearGradient(
        colors: [
          Color(0xFFFFDE59),
          Color(0xFFFF914D),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  // ---------------------------------------------------------------------------
  // Shared error popup
  // ---------------------------------------------------------------------------
  Future<void> _showErrorPopup(String message) async {
    await showDialog(
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

  // ---------------------------------------------------------------------------
  // Shared SUCCESS snackbar (green pill like MyStudyGroups)
  // ---------------------------------------------------------------------------
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
        backgroundColor: const Color(0xFF81C784), // green
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

  // ---------------------------------------------------------------------------
  // Time and Date
  // ---------------------------------------------------------------------------
  // ----- date & time formatting helpers -----
  String _formatDate(String yyyymmdd) {
    try {
      final parsed = DateTime.parse(yyyymmdd);
      return DateFormat('MMM d, yyyy').format(parsed); // e.g. Nov 11, 2025
    } catch (_) {
      return yyyymmdd; // fallback
    }
  }

  String _formatTime12(String time24h) {
    try {
      // assume "HH:mm"
      final parsed = DateTime.parse('2000-01-01 $time24h:00');
      return DateFormat('h:mm a').format(parsed); // e.g. 5:00 PM
    } catch (_) {
      return time24h; // fallback
    }
  }

  // ---------------------------------------------------------------------------
  // Load incoming + outgoing activity
  // ---------------------------------------------------------------------------
  Future<void> _loadActivities() async {
    if (!mounted) return;
    try {
      setState(() => _loading = true);

      final userGroups = await _service.listAllStudyGroups();
      final myInvites = await _service.listMyIncomingInvites();

      List<Map<String, dynamic>> incoming = [];
      List<StudyGroupResponse> outgoingJoin = [];
      List<Map<String, dynamic>> outgoingInv = [];

      // For every active group
      for (final group in userGroups) {
        // 1) If I'm the owner, I might have:
        //    - incoming join requests
        //    - outgoing invites to others
        if (group.access == "owner") {
          // Incoming join requests for this group
          final groupRequests =
              await _service.listIncomingRequests(group.id); // join requests
          for (var req in groupRequests) {
            incoming.add({
              "kind": "joinRequest",
              "groupId": group.id,
              "groupName": group.name,
              "userId": req['requesterId'],
              "userName": req['requesterName'],
              "userHandle": req['requesterHandle'],
            });
          }

          // Outgoing invites I (as owner) have sent for this group
          final groupInvites =
              await _service.listOutgoingInvites(group.id); // invites I sent
          for (var inv in groupInvites) {
            outgoingInv.add({
              "groupId": inv['groupId'],
              "groupName": inv['groupName'],
              "inviteeId": inv['inviteeId'],
              "inviteeHandle": inv['inviteeHandle'],
              "inviteeDisplayName": inv['inviteeDisplayName'],
              "ownerId": inv['ownerId'],
              "ownerHandle": inv['ownerHandle'],
              "ownerDisplayName": inv['ownerDisplayName'],
            });
          }
        }

        // 2) If I have a pending join-request TO some group
        if (group.hasPendingRequest == true) {
          outgoingJoin.add(group);
        }
      }

      // 3) Invites that were sent TO ME
      for (var inv in myInvites) {
        incoming.add({
          "kind": "invite",
          "groupId": inv['groupId'],
          "groupName": inv['groupName'],
          "userId": inv['ownerId'], // who invited me
          "userName": inv['ownerDisplayName'],
          "userHandle": inv['ownerHandle'],
          "inviteeId": inv['inviteeId'], // me
        });
      }

      if (!mounted) return;
      setState(() {
        incomingRequests = incoming;
        outgoingRequests = outgoingJoin;
        outgoingInvites = outgoingInv;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load activities: $e");
      if (!mounted) return;
      setState(() => _loading = false);
      await _showErrorPopup(
        e.toString().replaceFirst('Exception: ', 'Failed to load activities: '),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Accept / Decline (Incoming)
  // ---------------------------------------------------------------------------
  Future<void> acceptRequest(int index) async {
    final request = incomingRequests[index];
    final kind = request["kind"] as String? ?? "joinRequest";
    final groupId = request["groupId"] as String;
    final userId = request["userId"] as String; // requester or owner
    final inviteeId = request["inviteeId"] as String?;

    try {
      if (kind == "joinRequest") {
        // I'm the owner; accept someone's join request
        await _service.acceptIncomingRequest(
          groupId: groupId,
          requesterId: userId,
        );
      } else if (kind == "invite") {
        // I'm the invitee; accept the invite
        await _service.acceptGroupInvite(groupId);
      }

      setState(() {
        incomingRequests.removeAt(index);
      });

      // ✅ green success SnackBar
      _showSuccessSnackBar('Request accepted');
    } catch (e) {
      debugPrint("Failed to accept request: $e");
      await _showErrorPopup(
        e.toString().replaceFirst('Exception: ', 'Failed to accept request: '),
      );
    }
  }

  Future<void> declineRequest(int index) async {
    final request = incomingRequests[index];
    final kind = request["kind"] as String? ?? "joinRequest";
    final groupId = request["groupId"] as String;
    final userId = request["userId"] as String; // requester or owner
    final inviteeId = request["inviteeId"] as String?;

    try {
      if (kind == "joinRequest") {
        // I'm the owner; decline someone's join request
        await _service.declineIncomingRequest(
          groupId: groupId,
          requesterId: userId,
        );
      } else if (kind == "invite") {
        // I'm the invitee; decline my invite
        await _service.declineOrCancelGroupInvite(
          groupId,
          inviteeId ?? userId,
        );
      }

      setState(() {
        incomingRequests.removeAt(index);
      });

      // ✅ green success SnackBar
      _showSuccessSnackBar('Request declined');
    } catch (e) {
      debugPrint("Failed to decline request: $e");
      await _showErrorPopup(
        e
            .toString()
            .replaceFirst('Exception: ', 'Failed to decline request. Please refresh to verify request. '),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel outgoing
  // ---------------------------------------------------------------------------
  Future<void> cancelOutgoingRequest(String groupId) async {
    try {
      await _service.cancelMyJoinRequest(groupId);

      setState(() {
        outgoingRequests.removeWhere((g) => g.id == groupId);
      });

      // ✅ green success SnackBar
      _showSuccessSnackBar('Request cancelled');
    } catch (e) {
      debugPrint("Failed to cancel request: $e");
      await _showErrorPopup(
        e.toString().replaceFirst('Exception: ', 'Failed to cancel request: '),
      );
    }
  }

  Future<void> cancelOutgoingInvite(String groupId, String inviteeId) async {
    try {
      await _service.declineOrCancelGroupInvite(groupId, inviteeId);

      setState(() {
        outgoingInvites.removeWhere(
          (inv) => inv['groupId'] == groupId && inv['inviteeId'] == inviteeId,
        );
      });

      // ✅ green success SnackBar
      _showSuccessSnackBar('Invite cancelled');
    } catch (e) {
      debugPrint("Failed to cancel invite: $e");
      await _showErrorPopup(
        e.toString().replaceFirst('Exception: ', 'Failed to cancel invite: '),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------
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
                    "No incoming activity",
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
                  final groupName = request["groupName"] ?? "";
                  final userName = request["userName"] ?? "";
                  final userHandle = request["userHandle"] ?? "";

                  final subtitleText = (kind == "invite")
                      ? "$userName ($userHandle) invited you."
                      : "$userName ($userHandle) wants to join.";

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
                            'Are you sure you want to decline this ${kind == "invite" ? "invite" : "request"} from $userName?',
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
                        color: const Color(0xFFFFF7EB), // ← match StudyGroups
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
    final hasAny =
        outgoingRequests.isNotEmpty || outgoingInvites.isNotEmpty;

    if (!hasAny) {
      return const Center(
        child: Text(
          "No outgoing activity",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('outgoing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outgoingRequests.isNotEmpty) ...[
          const Text(
            "Join Requests",
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
                  color: const Color(0xFFFFF7EB),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 1,
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
                            "${_formatDate(group.date)} | "
                            "${_formatTime12(group.startTime)} - ${_formatTime12(group.endTime)}",
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
          const SizedBox(height: 24),
        ],
        if (outgoingInvites.isNotEmpty) ...[
          const Text(
            "Invitations",
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
              final groupName = inv['groupName'] ?? '';
              final inviteeName = inv['inviteeDisplayName'] ?? '';
              final inviteeHandle = inv['inviteeHandle'] ?? '';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7EB),
                  borderRadius: BorderRadius.circular(18),
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
                            groupName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Invited: $inviteeName ($inviteeHandle)",
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
                      onTap: () => cancelOutgoingInvite(
                        inv['groupId'],
                        inv['inviteeId'],
                      ),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
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
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        edgeOffset: 80, // prevents triggering system nav gesture
        displacement: 40, // smaller refresh animation
        child: Container(
          // ← vertical gradient
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFCF8), Color(0xFFFFF0C9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "My Activities",
                            style: TextStyle(
                              fontSize: 32.0,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'SuperLobster',
                            ),
                          ),
                          const Divider(thickness: 1.5, color: Colors.black),
                          const SizedBox(height: 20),

                          // My Study Groups button
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/mystudygroups'),
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

                          // Incoming / Outgoing toggle
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
                                    width: MediaQuery.of(context).size.width /
                                            2 -
                                        28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7E0),
                                      borderRadius: BorderRadius.circular(26),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.20),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 6),
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
                                              "Outgoing (${outgoingRequests.length + outgoingInvites.length})",
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

                          // Lists / loading (no Expanded, no inner RefreshIndicator)
                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            AnimatedSwitcher(
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
