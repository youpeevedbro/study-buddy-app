import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // <-- add this

import 'screens/landing.dart';
import 'screens/dashboard.dart';
import 'screens/profile.dart';
import 'screens/firebasecheckpage.dart';
import 'screens/activities.dart';
import 'screens/my_studygroups.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // <-- use options
  );
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
      // initialRoute: '/landing',
      initialRoute: '/firebase-check',
      routes: {
        '/landing'        : (_) => const LandingPage(),
        '/dashboard'      : (_) => const Dashboard(),
        '/profile'        : (_) => const UserProfilePage(),
        '/firebase-check' : (_) => const FirebaseCheckPage(),
        '/activities' : (_) => const MyActivitiesPage(),
        '/mystudygroups' : (_) => const MyStudyGroupsPage(),
      },
    );
  }
}
