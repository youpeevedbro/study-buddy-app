import 'package:flutter/material.dart';
import '../components/grad_button.dart';
import 'addgroup2.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../services/api.dart';


class MyStudyGroupsPage extends StatefulWidget {
  const MyStudyGroupsPage({super.key});

  @override
  State<MyStudyGroupsPage> createState() => _MyStudyGroupsPageState();
}

class _MyStudyGroupsPageState extends State<MyStudyGroupsPage> {



  void _navigateToAddGroup() async {
    // Wait for data from AddGroupPage
    final newGroup = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddGroupPage()),
    );

    // Add group if returned
    /*
    if (newGroup != null && newGroup is StudyGroup) {
      setState(() => _groups.add(newGroup));
    }*/

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

            // Add / Remove buttons
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
                  GradientButton(
                    onPressed: () {}, /*{
                      if (_groups.isNotEmpty) {
                        setState(() => _groups.removeLast());
                      }
                    },*/
                    borderRadius: BorderRadius.circular(12),
                    child: const Text(
                      "Remove",
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
                  child: const Groups(), 
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

  //late Future<List<JoinedGroup>> _futureGroups;
  @override
  void initState() {
    super.initState();
    _futureGroups = _service.listMyStudyGroups();
  } 

  
  void _reloadData() {
      setState(() {
        _futureGroups = _service.listMyStudyGroups(); // Re-assign the Future to trigger reload
      });
    } 

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: FutureBuilder<List<JoinedGroup>>(
        future: _futureGroups,
        builder: (BuildContext context, AsyncSnapshot<List<JoinedGroup>> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return 
              Text(
                'Error: ${snap.error}',
                style: const TextStyle(height: 1.3),
              );
      
          }
          final groups = snap.data ?? [];

          if (groups.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: Text(
                  'You have no current Study Groups.',
                  style: TextStyle(
                    fontSize: 18
                  ))),
              );
          }

          return GroupPanels(groups: groups, onReloadNeeded: _reloadData);
        }
      ),
    );
  }
}


class GroupPanels extends StatefulWidget {
  final VoidCallback onReloadNeeded;
  final List<JoinedGroup> groups;

  const GroupPanels({super.key, required this.groups, required this.onReloadNeeded});

  @override
  State<GroupPanels> createState() => _GroupPanelsState();
  }


class _GroupPanelsState extends State<GroupPanels> {
  bool _isDeleting = false;
  late List<JoinedGroup> _groups;
  late VoidCallback _onReloadNeeded;
  final GroupService _service = const GroupService();

  //late VoidCallback onReloadNeeded;

  
  @override
  void initState() {
    super.initState();
    _groups = widget.groups;
    _onReloadNeeded = widget.onReloadNeeded;
  }
  

  
  Future<void> _showDeleteConfirmationDialog(BuildContext context, String groupID) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete this Study Group?'),
          content: const Text('This Study Group will be permanently deleted and all members will be disbanded.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
              onPressed: _isDeleting ? null : () { 
                _handleDelete(groupID);
                //_onReloadNeeded();
                },
              child: _isDeleting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                ),
              ) : Text("Delete")
            ),
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
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
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
              title: Text(
                group.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isExpanded
                    ? theme.primaryColor
                    : Colors.black,
                )
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    group.date,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600
                    )),
                  Text('${group.startTime} - ${group.endTime}')
                ],
              )
            );
          },
          body: group.isExpanded  //when expanded -> query for more study group information
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
                return 
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      '${snap.error}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600
                      ),
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
                      Text("Location: ${groupResponse.buildingCode} - ${groupResponse.roomNumber}",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text("Owner: ${groupResponse.ownerDisplayName} (${groupResponse.ownerHandle})",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                          "${groupResponse.quantity} members: ${groupResponse.members}",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)
                      ),
                      const SizedBox(height: 8),
                    
                      if (groupResponse.access == "owner")... [
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: () => _showDeleteConfirmationDialog(context, groupResponse.id), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10), // Rounded corners
                              ),
                              maximumSize: Size(140,60)
                            ),
                            child: Text(
                              "DELETE",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700
                              )
                            ),
                          ),
                        ),
                      ],
                      if (groupResponse.access == "member")... [
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: (){}, 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10), // Rounded corners
                              ),
                              maximumSize: Size(140,60)
                            ),
                            child: Text(
                              "LEAVE",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700
                              )
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            }
          )
          : Container(),
          isExpanded: group.isExpanded,  //whether panel is currently expanded or not
        );
      }).toList(),
    );
  }
}