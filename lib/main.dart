import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'firebase_options.dart';

import 'screens/landing.dart';
import 'screens/dashboard.dart';
import 'screens/profile.dart';
import 'screens/findroom.dart';
import 'screens/firebasecheckpage.dart';
import 'screens/activities.dart';
import 'screens/my_studygroups.dart';
import 'screens/studygroup.dart';
import 'dart:io';
import 'screens/addgroup2.dart';
import 'screens/onboarding/create_profile.dart';
import 'screens/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  AppConfig.init();

  print(">>> BACKEND = ${AppConfig.apiBase}");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      initialRoute: '/landing',
      routes: {
        '/landing'        : (_) => const LandingPage(),
        '/dashboard'      : (context) => const Dashboard(),
        '/profile'        : (_) => const UserProfilePage(),
        '/firebase-check' : (_) => const FirebaseCheckPage(),
        '/activities'     : (_) => const MyActivitiesPage(),
        '/mystudygroups'  : (_) => const MyStudyGroupsPage(),
        '/rooms'          : (_) => const FindRoomPage(),
        '/studygroup'     : (_) => const StudyGroupsPage(),
        '/addgroup2'  : (_) => const AddGroupPage(),
        '/login': (context) => const LoginScreen(),
        '/createProfile': (context) => const CreateProfileScreen(),
      },
    );
  }
}
