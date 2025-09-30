import 'package:flutter/material.dart';
import 'pages/forgotpassword.dart';
import 'pages/dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyBuddyApp());
}

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9500)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const ForgotPasswordPage(),
    );
  }
}
