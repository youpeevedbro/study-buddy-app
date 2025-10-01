import 'package:flutter/material.dart';
//import 'pages/forgotpassword.dart';
//import 'pages/dashboard.dart';
import 'pages/home_page.dart';

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
      theme: ThemeData (
        useMaterial3: true,
        primaryColor: const Color(0xFFE7C144),
        hintColor: const Color(0xFFF0D689),

        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9500)),


        textTheme: TextTheme(
          displayLarge: TextStyle(fontFamily: 'BrittanySignature'),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
        )
      ),
      home: HomePage(),
    );
  }
}
