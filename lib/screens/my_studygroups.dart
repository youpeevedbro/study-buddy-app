import 'package:flutter/material.dart';
import '../components/grad_button.dart';
import 'addgroup2.dart';

class StudyGroup {
  final String name;
  final String location;
  final String date;
  final String startTime;
  final String endTime;
  final int max;

  StudyGroup({
    required this.name,
    required this.location,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.max,
  });
}

class MyStudyGroupsPage extends StatefulWidget {
  const MyStudyGroupsPage({super.key});

  @override
  State<MyStudyGroupsPage> createState() => _MyStudyGroupsPageState();
}

class _MyStudyGroupsPageState extends State<MyStudyGroupsPage> {
  List<StudyGroup> _groups = [
    StudyGroup(
      name: "Math Review Group",
      location: "ECS-302",
      date: "11/05/2025",
      startTime: "3:00 PM",
      endTime: "5:00 PM",
      max: 5,
    ),
    StudyGroup(
      name: "CS Project Team",
      location: "VEC-212",
      date: "11/08/2025",
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      max: 6,
    ),
  ];

  int _expandedIndex = -1;

  void _navigateToAddGroup() async {
    // Wait for data from AddGroupPage
    final newGroup = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddGroupPage()),
    );

    // Add group if returned
    if (newGroup != null && newGroup is StudyGroup) {
      setState(() => _groups.add(newGroup));
    }
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
                    onPressed: () {
                      if (_groups.isNotEmpty) {
                        setState(() => _groups.removeLast());
                      }
                    },
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
                  child: SingleChildScrollView(
                    child: ExpansionPanelList(
                      elevation: 0,
                      expandedHeaderPadding: EdgeInsets.zero,
                      expansionCallback: (panelIndex, isExpanded) {
                        setState(() {
                          _expandedIndex =
                              _expandedIndex == panelIndex ? -1 : panelIndex;
                        });
                      },
                      children: _groups.asMap().entries.map((entry) {
                        final index = entry.key;
                        final group = entry.value;
                        final isExpanded = _expandedIndex == index;

                        return ExpansionPanel(
                          canTapOnHeader: true,
                          backgroundColor: const Color(0xFFFCF6DB),
                          headerBuilder: (context, isExpanded) {
                            return ListTile(
                              title: Center(
                                child: Text(
                                  group.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isExpanded
                                        ? theme.primaryColor
                                        : Colors.black,
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
                                  Text("Location: ${group.location}",
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text("Date: ${group.date}",
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text(
                                      "Time: ${group.startTime} - ${group.endTime}",
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text("Max Participants: ${group.max}",
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          isExpanded: isExpanded,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
