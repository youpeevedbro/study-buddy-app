import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // === Firebase ===
  static late final String firebaseProjectId;
  static late final String firebaseStorageBucket;
  static late final String firebaseSenderId;
  static late final String firebaseAndroidAppId;
  static late final String firebaseIosAppId;

  /// URL Firebase uses to complete OAuth flows (login callback).
  /// Default: https://<project>.firebaseapp.com/__/auth/handler
  static late final String firebaseHandlerUrl;

  /// Where Azure AD (Entra) should redirect AFTER logout (your hosted page).
  /// Default: https://<project>.web.app/signed-out/
  static late final String aadPostLogoutUrl;

  // === Microsoft / Entra ===
  /// Tenant GUID (can be empty; if empty we skip AAD front-channel logout).
  static late final String microsoftTenantId;

  // === App settings ===
  /// Legacy single-domain hint (kept for back-compat).
  static late final String allowedEmailDomain;

  /// New: list of allowed email domain suffixes, e.g. ['@student.csulb.edu', '@csulb.edu'].
  static late final List<String> allowedEmailDomains;

  /// FastAPI backend base URL (per-platform overrides supported).
  static late final String apiBase;

  static void init() {
    // ---- Firebase ----
    firebaseProjectId     = _read('FIREBASE_PROJECT_ID',     def: 'studybuddy-e8dba');
    firebaseStorageBucket = _read('FIREBASE_STORAGE_BUCKET', def: 'studybuddy-e8dba.firebasestorage.app');
    firebaseSenderId      = _read('FIREBASE_SENDER_ID',      def: '157338247439');
    firebaseAndroidAppId  = _read('FIREBASE_ANDROID_APP_ID', def: '');
    firebaseIosAppId      = _read('FIREBASE_IOS_APP_ID',     def: '');

    firebaseHandlerUrl = _read(
      'FIREBASE_HANDLER_URL',
      def: 'https://$firebaseProjectId.firebaseapp.com/__/auth/handler',
    );

    // ---- AAD ----
    aadPostLogoutUrl  = _read('AAD_POST_LOGOUT_URL', def: '');
    microsoftTenantId = _read('MICROSOFT_TENANT_ID', def: '');

    // ---- App: allowed email domains ----
    // Legacy single-domain value with '@' included.
    allowedEmailDomain = _read('ALLOWED_EMAIL_DOMAIN', def: '@student.csulb.edu').toLowerCase();

    // New multi-domain env: ALLOWED_EMAIL_DOMAINS=student.csulb.edu,csulb.edu
    final multiRaw = dotenv.maybeGet('ALLOWED_EMAIL_DOMAINS')?.trim() ?? '';

    if (multiRaw.isNotEmpty) {
      final parsed = multiRaw
          .split(',')
          .map((d) => d.trim().toLowerCase())
          .where((d) => d.isNotEmpty)
          .map((d) => d.startsWith('@') ? d : '@$d')
          .toList();

      if (parsed.isNotEmpty) {
        allowedEmailDomains = parsed;
      } else if (allowedEmailDomain.isNotEmpty) {
        allowedEmailDomains = [allowedEmailDomain];
      } else {
        allowedEmailDomains = const [];
      }
    } else if (allowedEmailDomain.isNotEmpty) {
      // Fallback: only the legacy single domain.
      allowedEmailDomains = [allowedEmailDomain];
    } else {
      allowedEmailDomains = const [];
    }

    // ---- API Base URL selection ----
    final envBaseIOS     = dotenv.maybeGet('API_BASE_IOS')?.trim();
    final envBaseAndroid = dotenv.maybeGet('API_BASE_ANDROID')?.trim();
    final envBaseWeb     = dotenv.maybeGet('API_BASE_WEB')?.trim();
    final envBaseGlobal  = dotenv.maybeGet('API_BASE')?.trim(); // optional fallback

    // IMPORTANT: kIsWeb check must come BEFORE any Platform.* usage.
    if (kIsWeb) {
      // For web, either define API_BASE_WEB in .env,
      // or just reuse API_BASE (point both at your Cloud Run URL).
      apiBase = envBaseWeb ??
          envBaseGlobal ??
          'https://studybuddy-backend-157338247439.us-central1.run.app'; // <- put your prod backend here as last resort
    } else if (Platform.isAndroid && envBaseAndroid != null && envBaseAndroid.isNotEmpty) {
      apiBase = envBaseAndroid;
    } else if ((Platform.isIOS || Platform.isMacOS) && envBaseIOS != null && envBaseIOS.isNotEmpty) {
      apiBase = envBaseIOS;
    } else if (envBaseGlobal != null && envBaseGlobal.isNotEmpty) {
      apiBase = envBaseGlobal;
    } else if (Platform.isAndroid) {
      // Android emulator
      apiBase = 'http://10.0.2.2:8000';
    } else {
      // iOS simulator / macOS / other
      apiBase = 'http://127.0.0.1:8000';
    }

    if (apiBase.isEmpty) {
      throw StateError(
        'No API base URL configured. Set API_BASE (and optionally API_BASE_WEB / API_BASE_ANDROID / API_BASE_IOS) in .env.',
      );
    }

    debugPrint(
      '✅ AppConfig: project=$firebaseProjectId apiBase=$apiBase '
          'tenant=$microsoftTenantId postLogout=$aadPostLogoutUrl '
          'allowedDomains=${allowedEmailDomains.join(", ")}',
    );
  }

  // Safe reader w/ default
  static String _read(String key, {String def = ''}) {
    final v = dotenv.maybeGet(key)?.trim();
    if (v == null || v.isEmpty) {
      debugPrint('⚠️ .env missing $key — using default "$def"');
      return def;
    }
    return v;
  }

  // Back-compat alias used in older widgets
  static String get allowedDomain => allowedEmailDomain;
}
