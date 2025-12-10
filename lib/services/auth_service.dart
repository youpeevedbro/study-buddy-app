// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Helper: check if an email is in one of the allowed domains.
  bool _isAllowedEmail(String email) {
    final lower = email.trim().toLowerCase();
    if (lower.isEmpty) return false;

    final domains = AppConfig.allowedEmailDomains;
    if (domains.isNotEmpty) {
      return domains.any((suffix) => lower.endsWith(suffix.toLowerCase()));
    }

    // Fallback: legacy single domain
    final single = AppConfig.allowedDomain.trim().toLowerCase();
    if (single.isEmpty) return true; // no restriction configured
    return lower.endsWith(single);
  }

  String _allowedDomainDescription() {
    final domains = AppConfig.allowedEmailDomains;
    if (domains.isNotEmpty) {
      // domains already include '@'
      if (domains.length == 1) return domains.first;
      if (domains.length == 2) return '${domains[0]} or ${domains[1]}';
      return domains.join(', ');
    }
    return AppConfig.allowedDomain;
  }

  /// Sign in with CSULB SSO (OIDC via Firebase) with a forced fresh prompt.
  /// Provider ID must match Firebase Auth → OpenID Connect config.
  Future<UserCredential> signInWithCsulb() async {
    final provider = OAuthProvider('oidc.microsoft-csulb')
      ..setCustomParameters(<String, String>{
        'prompt': 'select_account', // force account chooser every time
        'max_age': '0',             // require fresh auth
      });

    // --- Platform-specific sign-in ---
    UserCredential cred;
    if (kIsWeb) {
      // Web: use popup/redirect flow from Firebase Auth Web SDK
      // Popup is usually nicer; switch to signInWithRedirect if popups are blocked.
      cred = await _auth.signInWithPopup(provider);
      // cred = await _auth.signInWithRedirect(provider);
    } else {
      // iOS / Android / desktop: use the normal provider API
      cred = await _auth.signInWithProvider(provider);
    }

    // ---- Enforce allowed domains from AppConfig (multi-domain aware)
    final email = cred.user?.email ?? '';
    if (!_isAllowedEmail(email)) {
      await _auth.signOut();

      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Use your ${_allowedDomainDescription()} email address.',
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
    final e = email.trim().toLowerCase();
    if (!_isAllowedEmail(e)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Use your ${_allowedDomainDescription()} email address.',
      );
    }

    return _auth.signInWithEmailAndPassword(
      email: e,
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
    if (!_isAllowedEmail(e)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Use your ${_allowedDomainDescription()} email address.',
      );
    }
    await _auth.sendPasswordResetEmail(email: e);
  }

  // Optional metadata helper
  Future<String> appPackageName() async =>
      (await PackageInfo.fromPlatform()).packageName;
}
