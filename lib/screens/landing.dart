// lib/screens/landing.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/grad_button.dart';
import '../services/user_service.dart'; // 👈 NEW

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _busy = false;

  // If your Provider ID in Firebase Console is different, edit here:
  static const String _oidcProviderId = 'oidc.microsoft-csulb';

  /// Decide where to go after a successful login:
  /// - If profile exists in Firestore → /dashboard
  /// - If not → /createProfile
  Future<void> _routeAfterLogin() async {
    final hasProfile = await UserService.instance.currentUserProfileExists();

    if (!mounted) return;

    if (hasProfile) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/createProfile');
    }
  }

  Future<void> _doMicrosoftLogin() async {
    setState(() => _busy = true);
    try {
      final provider = OAuthProvider(_oidcProviderId);
      await FirebaseAuth.instance.signInWithProvider(provider);

      if (!mounted) return;

      // 👇 instead of going straight to /dashboard,
      //    check whether the user has a profile doc
      await _routeAfterLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Sign-in failed: ${e.code} — ${e.message ?? ''}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Study Buddy',
                style: TextStyle(
                  fontFamily: 'BrittanySignature',
                  fontSize: 48,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: GradientButton(
                          width: double.infinity,
                          height: 56,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _busy ? null : _doMicrosoftLogin,
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Sign in with Microsoft (CSULB)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
