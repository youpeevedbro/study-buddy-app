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
        'prompt': 'select_account', // force account chooser
        'max_age': '0',             // require fresh auth
        // 'domain_hint': 'csulb.edu', // optional UX hint
      });
    return _auth.signInWithProvider(provider);
  }

  /// Optional alias if other code calls this name.
  Future<void> signInWithMicrosoft() async {
    await signInWithCsulb();
  }

  /// Logout from Firebase and Microsoft (tenant-specific).
  /// Uses your configured post-logout URL (prefer AAD_POST_LOGOUT_URL, fallback to Firebase handler).
  Future<void> logout() async {
    final tenantId = AppConfig.microsoftTenantId.trim();
    final postLogout = (AppConfig.aadPostLogoutUrl.isNotEmpty
            ? AppConfig.aadPostLogoutUrl
            : AppConfig.firebaseHandlerUrl)
        .trim();

    // Capture email BEFORE Firebase signOut(), for logout_hint (optional).
    final email = _auth.currentUser?.email ?? '';

    // 1) Firebase sign out (local)
    await _auth.signOut();

    // 2) AAD logout to clear Microsoft cookies (skip if tenant unknown)
    if (tenantId.isEmpty) return;

    final url = Uri.parse(
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/logout'
      '?post_logout_redirect_uri=${Uri.encodeComponent(postLogout)}'
      '${email.isNotEmpty ? '&logout_hint=${Uri.encodeComponent(email)}' : ''}',
    );

    // External browser works on both iOS & Android.
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Even if this fails, Firebase is signed out; next sign-in still forces prompt.
    }
  }

  /// Forgot-password helper (only for Email/Password accounts).
  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (AppConfig.allowedDomain.isNotEmpty && !e.endsWith(AppConfig.allowedDomain)) {
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
