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

  // ----------------------------------------------------------
  // Loading state & incoming requests
  // ----------------------------------------------------------
  bool _loading = true;
  List<Map<String, dynamic>> incomingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadIncomingRequests();
  }

  // ----------------------------------------------------------
  // Load incoming requests for groups where user is owner
  // ----------------------------------------------------------
  Future<void> _loadIncomingRequests() async {
    try {
      setState(() => _loading = true);

      final userGroups = await _service.listAllStudyGroups();
      List<Map<String, dynamic>> requests = [];

      for (var group in userGroups) {
        // Only fetch requests if current user is the owner
        if (group.access == "owner") {
          final groupRequests = await _service.listIncomingRequests(group.id);
          for (var req in groupRequests) {
            requests.add({
              "groupId": group.id,
              "groupName": group.name,
              "requesterId": req['requesterId'],
              "requesterHandle": req['requesterHandle'],
              "requesterName": req['requesterName'],
            });
          }
        }
      }

      setState(() {
        incomingRequests = requests;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load incoming requests: $e");
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load requests: $e')),
      );
    }
  }

  // ----------------------------------------------------------
  // Accept / Decline
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
              // PAGE TITLE
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
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/mystudygroups'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  fixedSize: const Size.fromHeight(60),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("My Study Groups"),
              ),

              const SizedBox(height: 70),

              // INCOMING REQUESTS SECTION HEADER
              const Text(
                "Incoming Requests",
                style: TextStyle(
                  fontSize: 25,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(thickness: 1.5, color: Colors.black),
              const SizedBox(height: 10),
              const Text(
                'Swipe right to accept requests, left to decline.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),

              // REQUEST LIST / LOADING / EMPTY STATE
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : incomingRequests.isEmpty
                        ? const Center(
                            child: Text(
                              "No incoming requests",
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: incomingRequests.length,
                            itemBuilder: (context, index) {
                              final request = incomingRequests[index];
                              return Dismissible(
                                key: ValueKey('${request["groupId"]}_${request["requesterId"]}_$index'),
                                direction: DismissDirection.horizontal,
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
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
                                    borderRadius: BorderRadius.circular(12),
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
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                                      color: Colors.white,
                                      child: Row(
                                        children: [
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
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Text(
                                            "← Swipe →",
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, thickness: 0.6, color: Colors.black12),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
