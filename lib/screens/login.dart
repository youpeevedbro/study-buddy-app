import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _emailErr, _passErr, _globalErr;

  static const allowedDomain = '@csulb.edu';

  final yellow = const Color(0xFFFFC72A);
  final dark = const Color(0xFF111827);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String placeholder, {String? errorText}) {
    return InputDecoration(
      hintText: placeholder,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFFFFC72A), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Sign-in failed.';
    }
  }

  /// After any successful login, decide where to send the user:
  /// - if they have a profile → /dashboard
  /// - if they don't → /createProfile
  Future<void> _routeAfterLogin() async {
    final hasProfile = await UserService.instance.currentUserProfileExists();

    if (!mounted) return;

    if (hasProfile) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Navigator.of(context).pushReplacementNamed('/createProfile');
    }
  }

  Future<void> _signInEmail() async {
    setState(() {
      _busy = true;
      _emailErr = _passErr = _globalErr = null;
    });

    try {
      final email = _email.text.trim().toLowerCase();
      final pwd = _password.text;

      if (!email.endsWith(allowedDomain)) {
        setState(() => _emailErr = 'Please use your CSULB email address.');
        return;
      }
      if (pwd.isEmpty) {
        setState(() => _passErr = 'Please enter your password.');
        return;
      }

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pwd);

      // 🔥 Instead of going straight to /dashboard, check profile first
      await _routeAfterLogin();
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('password')) {
        _passErr = _friendly(e);
      } else if (code.contains('user') || code.contains('email')) {
        _emailErr = _friendly(e);
      } else {
        _globalErr = _friendly(e);
      }
      setState(() {});
    } catch (_) {
      setState(() => _globalErr = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithMicrosoft() async {
    setState(() {
      _busy = true;
      _globalErr = null;
    });

    try {
      // ✅ Use your AuthService wrapper (CSULB SSO via OIDC)
      await AuthService.instance.signInWithCsulb();

      // 🔥 After SSO succeeds, check Firestore profile
      await _routeAfterLogin();
    } on FirebaseAuthException catch (e) {
      setState(() => _globalErr = _friendly(e));
    } catch (_) {
      setState(() => _globalErr = 'Microsoft sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 240,
                    child: Image.network(
                      'https://studybuddylogo.netlify.app/assets/studybuddy_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Email/password (you can keep or remove later)
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email
                    ],
                    decoration:
                        _inputDecoration('Email', errorText: _emailErr),
                    style: TextStyle(color: dark, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration:
                        _inputDecoration('Password', errorText: _passErr),
                    style: TextStyle(color: dark, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _signInEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: dark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _busy
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Sign in with Email',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Microsoft SSO
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _signInWithMicrosoft,
                      child:
                          const Text('Sign in with Microsoft (CSULB)'),
                    ),
                  ),

                  if (_globalErr != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _globalErr!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
