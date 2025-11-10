// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  // ---- Streams & session helpers ----
  Stream<User?> get onAuthStateChanged => FirebaseAuth.instance.authStateChanges();
  Future<User?> currentUser() async => FirebaseAuth.instance.currentUser;
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
  Future<bool> isLoggedIn() async => FirebaseAuth.instance.currentUser != null;

  // ---- Email / Password ----
  Future<void> signInWithEmail(String rawEmail, String password) async {
    final email = rawEmail.trim().toLowerCase();
    if (!email.endsWith(AppConfig.allowedDomain)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Please use your ${AppConfig.allowedDomain} email address.',
      );
    }
    if (password.isEmpty) {
      throw FirebaseAuthException(code: 'missing-password', message: 'Please enter your password.');
    }
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String rawEmail, String password) async {
    final email = rawEmail.trim().toLowerCase();
    if (!email.endsWith(AppConfig.allowedDomain)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Please use your ${AppConfig.allowedDomain} email address.',
      );
    }
    if (password.length < 6) {
      throw FirebaseAuthException(code: 'weak-password', message: 'Password must be 6+ characters.');
    }
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    if (!email.endsWith(AppConfig.allowedDomain)) {
      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Please use your ${AppConfig.allowedDomain} email address.',
      );
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  // ---- Microsoft (OIDC) via Firebase ----
  // Must match the Provider ID you created in Firebase Auth → OpenID Connect
  static const _oidcProviderId = 'oidc.microsoft-csulb';

  bool _signingIn = false;

  Future<void> signInWithMicrosoft() async {
    if (_signingIn) return; // single-flight guard
    _signingIn = true;
    try {
      // Clear any local session to avoid silent SSO.
      await FirebaseAuth.instance.signOut();

      final provider = OAuthProvider(_oidcProviderId);
      // Ensure the user is prompted each time (no auto SSO).
      provider.setCustomParameters({'prompt': 'login'});

      await FirebaseAuth.instance.signInWithProvider(provider);
    } finally {
      _signingIn = false;
    }
  }

  // ---- Logout (Firebase + AAD front-channel to your hosted page) ----
  Future<void> logout() async {
    // 1) Always clear Firebase session first.
    await FirebaseAuth.instance.signOut();

    // 2) Also clear Microsoft cookie to avoid auto SSO on next login.
    final tenant = AppConfig.microsoftTenantId;
    final after = AppConfig.aadPostLogoutUrl; // hosted /signed-out/ page
    if (tenant.isEmpty || after.isEmpty) return;

    final aadLogout = Uri.parse(
      'https://login.microsoftonline.com/$tenant/oauth2/v2.0/logout'
          '?post_logout_redirect_uri=${Uri.encodeComponent(after)}',
    );

    try {
      await launchUrl(aadLogout, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Even if this fails, Firebase is signed out, and sign-in uses prompt=login.
    }
  }

  // ---- Optional metadata helper ----
  Future<String> appPackageName() async =>
      (await PackageInfo.fromPlatform()).packageName;
}
