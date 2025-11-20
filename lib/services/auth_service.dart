// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Convenience getter for the current Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Returns true if a Firebase user is currently signed in.
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  /// Sign in with CSULB SSO (OIDC via Firebase) with a forced fresh prompt.
  /// Provider ID must match Firebase Auth → OpenID Connect config.
  Future<UserCredential> signInWithCsulb() async {
    final provider = OAuthProvider('oidc.microsoft-csulb')
      ..setCustomParameters(<String, String>{
        'prompt': 'select_account', // force account chooser every time
        'max_age': '0',             // require fresh auth
      });

    // Step 1 — Perform sign-in via Firebase
    final cred = await _auth.signInWithProvider(provider);

    // Step 2 — Enforce required domain from .env (ALLOWED_EMAIL_DOMAIN)
    final email = cred.user?.email ?? '';
    final lower = email.toLowerCase();

    if (AppConfig.allowedDomain.isNotEmpty &&
        !lower.endsWith(AppConfig.allowedDomain.trim().toLowerCase())) {
      await _auth.signOut();

      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Use your ${AppConfig.allowedDomain} email address.',
      );
    }

    return cred;
  }

  /// Optional alias if other code calls this name.
  Future<void> signInWithMicrosoft() async {
    await signInWithCsulb();
  }

  /// Email/password sign-in wrapper (if you ever use it anywhere).
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Simple app-level logout:
  /// - Sign out of Firebase
  /// - NO browser / SSO logout page at all (no redirect, no url_launcher)
  Future<void> signOut() async {
    await _auth.signOut();

    // Debug once if needed:
    // ignore: avoid_print
    print('After Firebase signOut: ${_auth.currentUser}');
  }

  /// Back-compat alias for any old calls.
  Future<void> logout() => signOut();

  /// Forgot-password helper (only for Email/Password accounts).
  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (AppConfig.allowedDomain.isNotEmpty &&
        !e.endsWith(AppConfig.allowedDomain.trim().toLowerCase())) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Use your ${AppConfig.allowedDomain} email address.',
      );
    }
    await _auth.sendPasswordResetEmail(email: e);
  }

  // Optional metadata helper
  Future<String> appPackageName() async =>
      (await PackageInfo.fromPlatform()).packageName;
}
