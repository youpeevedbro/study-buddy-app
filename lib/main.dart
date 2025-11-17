import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';      // 👈 ADD THIS

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
import 'screens/addgroup2.dart';
import 'screens/onboarding/create_profile.dart';
import 'screens/login.dart';
// import 'dart:io';  // 👈 Not needed here, you can remove this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  AppConfig.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StudyBuddyApp());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for Firebase to load
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // If not logged in → go to landing page
        if (user == null) {
          return const LandingPage();
        }

        // Logged in → go to dashboard
        // 👇 use whatever your dashboard widget is actually called
        return const Dashboard(); 
      },
    );
  }
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

      // 🔴 OLD:
      // initialRoute: '/landing',

      // ✅ NEW: start the app at AuthGate so it reacts to login/logout
      home: const AuthGate(),

      routes: {
        '/landing'        : (_) => const LandingPage(),
        '/dashboard'      : (_) => const Dashboard(),
        '/profile'        : (_) => const UserProfilePage(),
        '/firebase-check' : (_) => const FirebaseCheckPage(),
        '/activities'     : (_) => const MyActivitiesPage(),
        '/mystudygroups'  : (_) => const MyStudyGroupsPage(),
        '/rooms'          : (_) => const FindRoomPage(),
        '/studygroup'     : (_) => const StudyGroupsPage(),
        '/addgroup2'      : (_) => const AddGroupPage(),
        '/login'          : (_) => const LoginScreen(),
        '/createProfile'  : (_) => const CreateProfileScreen(),
      },
    );
  }
}
