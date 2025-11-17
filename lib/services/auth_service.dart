import 'package:firebase_auth/firebase_auth.dart';
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
        'prompt': 'select_account',
        'max_age': '0',
      });

    // 🔥 Step 1 — Perform the actual sign-in
    final cred = await _auth.signInWithProvider(provider);

    // 🔥 Step 2 — Enforce required domain here
    final email = cred.user?.email ?? '';
    final lower = email.toLowerCase();

    if (AppConfig.allowedDomain.isNotEmpty &&
        !lower.endsWith(AppConfig.allowedDomain.trim().toLowerCase())) {

      await _auth.signOut(); // sign back out (because this account is not allowed)

      throw FirebaseAuthException(
        code: 'invalid-email-domain',
        message: 'Use your ${AppConfig.allowedDomain} email address.',
      );
    }

    // 🔥 If domain is allowed → return success
    return cred;
  }


  /// Optional alias if other code calls this name.
  Future<void> signInWithMicrosoft() async {
    await signInWithCsulb();
  }

  /// Logout from Firebase (app-level logout).
  /// We rely on `prompt` / `max_age` on sign-in to avoid silent SSO reuse.
  Future<void> signOut() async {
    await _auth.signOut();
    // Debug once on iOS to confirm it's really null:
    // ignore: avoid_print
    print('After Firebase signOut: ${_auth.currentUser}');
  }

    /// Email/password sign-in wrapper.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// If your older code calls `logout()`, keep this as a shim so nothing breaks.
  Future<void> logout() => signOut();

  /// Forgot-password helper (only for Email/Password accounts).
  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (AppConfig.allowedDomain.isNotEmpty &&
        !e.endsWith(AppConfig.allowedDomain)) {
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
