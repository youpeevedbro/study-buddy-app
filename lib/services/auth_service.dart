import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    // Step 1 — Perform sign-in
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

  /// Email/password sign-in wrapper.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Internal helper to hit the AAD logout endpoint and show the
  /// "logging you out" / "you have been logged out" pages.
  Future<void> _aadFrontChannelLogout(String? email) async {
    final tenantId = AppConfig.microsoftTenantId.trim();
    if (tenantId.isEmpty) return; // nothing to do if not configured

    final postLogout = (AppConfig.aadPostLogoutUrl.isNotEmpty
        ? AppConfig.aadPostLogoutUrl
        : AppConfig.firebaseHandlerUrl)
        .trim();

    final uri = Uri.parse(
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/logout'
          '?post_logout_redirect_uri=${Uri.encodeComponent(postLogout)}'
          '${(email != null && email.isNotEmpty)
          ? '&logout_hint=${Uri.encodeComponent(email)}'
          : ''}',
    );

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Even if this fails, Firebase is signed out; next sign-in still forces prompt.
    }
  }

  /// App-level logout: Firebase + Microsoft (AAD) front-channel logout.
  Future<void> signOut() async {
    // Capture email BEFORE signOut so we can send logout_hint.
    final emailBefore = _auth.currentUser?.email;

    // 1) Firebase sign out (local app session)
    await _auth.signOut();

    // 2) AAD logout to clear Microsoft cookies + show logout pages
    await _aadFrontChannelLogout(emailBefore);

    // Debug once if needed:
    // ignore: avoid_print
    print('After Firebase signOut: ${_auth.currentUser}');
  }

  /// Back-compat alias.
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

  User? get currentUser => _auth.currentUser;

  // Optional metadata helper
  Future<String> appPackageName() async =>
      (await PackageInfo.fromPlatform()).packageName;
}
