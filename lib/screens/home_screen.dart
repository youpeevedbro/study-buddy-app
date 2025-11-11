import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_client.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _testRooms() async {
    final resp = await apiGet('/rooms'); // GET https://YOUR_API/rooms with Bearer token
    debugPrint('Rooms response: ${resp.statusCode} ${resp.body}');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyBuddy'),
        actions: [
          IconButton(
            onPressed: () async { await FirebaseAuth.instance.signOut(); },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hello, ${user?.email ?? user?.uid}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testRooms,
              child: const Text('Call /rooms'),
            ),
          ],
        ),
      ),
    );
  }
}
