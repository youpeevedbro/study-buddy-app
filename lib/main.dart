import 'package:flutter/material.dart';
import 'screens/landing.dart';
import 'screens/dashboard.dart';
import 'screens/profile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyBuddyApp());
}

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFFC72A);

    return MaterialApp(
      title: 'Study Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/landing',
      routes: {
        '/landing'   : (_) => const LandingPage(),
        '/dashboard' : (_) => const Dashboard(),
        '/profile'   : (_) => const UserProfilePage(),
      },
    );
  }
}
