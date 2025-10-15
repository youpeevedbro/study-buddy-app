import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseCheckPage extends StatefulWidget {
  const FirebaseCheckPage({super.key});
  
  @override
  State<FirebaseCheckPage> createState() => _FirebaseCheckPageState();
}

class _FirebaseCheckPageState extends State<FirebaseCheckPage> {
  String status = 'Press the button to test';

  Future<void> _ping() async {
    setState(() => status = 'Writing…');
    try {
      final ref = FirebaseFirestore.instance.collection('diagnostics').doc('ping');
      await ref.set({'ok': true, 'time': FieldValue.serverTimestamp()});
      setState(() => status = 'Write OK. Reading…');
      final snap = await ref.get();
      setState(() => status = 'Read OK: ${snap.data()}');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Check')),
      body: Center(child: Text(status, textAlign: TextAlign.center)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ping,
        label: const Text('Ping Firestore'),
      ),
    );
  }
}
