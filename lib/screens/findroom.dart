// Find Room screen, logic can be implemented later, should be connect to dashboard
import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'filter.dart'; // Import the filter page

class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
  // Dummy room list (replace with Firestore or backend data)
  final List<String> _rooms = [
    "Room 1",
    "Room 2",
    "Room 3",
    "Room 4",
    "Room 5"
  ];

  String? _selectedRoom;

  void _openFilterPopup() async {
  // Opens the Filter page as a modern bottom sheet
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true, // allows full height scroll
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (context) => const FilterPage(), // call filter.dart widget
  );
}

  void _selectRoom(String room) {
    setState(() {
      _selectedRoom = room;
    });
    print("Selected: $room");
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
                // App Title (Study Buddy)
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

                const SizedBox(height: 20),

                // Find Room Header + Filter Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
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

                const SizedBox(height: 10),

                // Scrollable List of Rooms
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFFADA7A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(15),
                      child: ListView.builder(
                        itemCount: _rooms.length,
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          final isSelected = _selectedRoom == room;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: GestureDetector(
                              onTap: () => _selectRoom(room),
                              child: Container(
                                height: 45,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Color(0xFFFCF6DB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: theme.primaryColor,
                                          width: 2,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 4,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  room,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? theme.primaryColor
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 20,
              left: 25,
              child: IconButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Dashboard()),
                  );
                },
                icon: Transform.translate(
                      offset: const Offset(3.0, 0.0), 
                      child: Icon(Icons.arrow_back_ios, color: Colors.black),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
