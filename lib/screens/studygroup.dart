// Study Groups screen
import 'package:flutter/material.dart';
import 'dashboard.dart';
import '../components/grad_button.dart';

class StudyGroupsPage extends StatefulWidget {
  const StudyGroupsPage({super.key});

  @override
  State<StudyGroupsPage> createState() => _StudyGroupsPageState();
}

class _StudyGroupsPageState extends State<StudyGroupsPage> {
  // Dummy data for study groups
  final List<Map<String, dynamic>> _groups = [
    {
      "name": "Data Structures Study Group",
      "time": "Mon, 3:00 PM - 5:00 PM",
      "location": "Library Room 204",
      "status": "Open for new members"
    },
    {
      "name": "Algorithms Review Session",
      "time": "Wed, 6:00 PM - 8:00 PM",
      "location": "EN2 - 310",
      "status": "By Invitation Only" // Should be full or by invitation only??
    },
    {
      "name": "Machine Learning Study Group",
      "time": "Fri, 2:00 PM - 4:00 PM",
      "location": "VEC - 120",
      "status": "Open for new members"
    },
    {
      "name": "CSULB Finals Prep Group",
      "time": "Sat, 1:00 PM - 3:00 PM",
      "location": "COB - 205",
      "status": "Open for new members"
    },
  ];

  int _expandedIndex = -1;

  void _sendJoinRequest(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Join request sent to ${_groups[index]["name"]}"),
      ),
    );
    // TODO: Implement backend join request logic
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App title
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    'Study Buddy',
                    style: const TextStyle(
                      fontFamily: 'BrittanySignature',
                      fontSize: 36,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Header
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
                                      group["name"],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Time: ${group["time"]}",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Location: ${group["location"]}",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Status: ${group["status"]}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: group["status"] == "By Invitation Only"
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (group["status"] != "By Invitation Only") ...[
                                        const SizedBox(height: 12),
                                        Center(
                                          child: GradientButton(
                                            height: 35,
                                            borderRadius: BorderRadius.circular(12.0),
                                            onPressed: () => _sendJoinRequest(index),
                                            child: const Text(
                                              "Send Join Request",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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

            // Back button
            Positioned(
              top: 20,
              left: 25,
              child: IconButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Dashboard()),
                  );
                },
                icon: Transform.translate(
                  offset: const Offset(3.0, 0.0),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
