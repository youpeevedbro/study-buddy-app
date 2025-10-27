// Find Room screen 
import 'package:flutter/material.dart';
import 'filter.dart'; // Import the filter page
import '../components/grad_button.dart';  

class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
  final List<Map<String, dynamic>> _rooms = [
    {"name": "Room 1", "location": "EN2 - 312", "lockedReports": 3},
    {"name": "Room 2", "location": "Library - 408", "lockedReports": 0},
    {"name": "Room 3", "location": "Science Hall 105", "lockedReports": 1},
    {"name": "Room 4", "location": "HC - 120", "lockedReports": 0},
  ];

  int _expandedIndex = -1;
  FilterCriteria? _currentFilter;

  // Filter modal
  void _openFilterPopup() async {
    final result = await showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => FilterPage(initialFilters: _currentFilter),
    );

    if (result != null) {
      setState(() => _currentFilter = result);
      print('Applied Filters: ${result.toJson()}');
      // TODO: Apply backend filtering logic here later
    }
  }

  void _reportLocked(int index) {
    setState(() {
      _rooms[index]["lockedReports"]++;
    });
    // TODO: Update Firestore or backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${_rooms[index]["name"]} reported as locked")),
    );
  }

  void _checkIn(int index) {
    // TODO: Implement backend check-in logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You checked into ${_rooms[index]["name"]}")),
    );
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
          onPressed: () => Navigator.pop(context), // back to Dashboard
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header row
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Find Room",
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: _openFilterPopup,
                        icon: const Icon(Icons.filter_list, size: 28),
                      ),
                    ],
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

                // Expandable room list
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
                          children: _rooms.asMap().entries.map((entry) {
                            final index = entry.key;
                            final room = entry.value;
                            final isExpanded = _expandedIndex == index;

                            return ExpansionPanel(
                              canTapOnHeader: true,
                              backgroundColor: const Color(0xFFFCF6DB),
                              headerBuilder: (context, isExpanded) {
                                return ListTile(
                                  title: Center(
                                    child: Text(
                                      room["name"],
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
                                        "Location: ${room["location"]}",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      if (room["lockedReports"] > 0)
                                        Text(
                                          "${room["lockedReports"]} student(s) reported this room as LOCKED",
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Report Locked
                                          GradientButton(
                                              height: 35,
                                              borderRadius: BorderRadius.circular(12.0),
                                              onPressed: () => _reportLocked(index),
                                              child: const Text(
                                                'Locked',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16.0,
                                                ),
                                                ),
                                            ),

                                          // Check-in
                                          GradientButton(
                                              height: 35,
                                              borderRadius: BorderRadius.circular(12.0),
                                              onPressed: () => _checkIn(index),
                                              child: const Text(
                                                'Check-in',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16.0,
                                                ),
                                                ),
                                            ),
                                        ],
                                      ),
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
          ],
        ),
      ),
    );
  }
}
