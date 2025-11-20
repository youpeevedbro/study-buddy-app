import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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
  /// Client-side hint only; your backend enforces allowed domains.
  static late final String allowedEmailDomain;

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
    // aadPostLogoutUrl  = _read(
    //   'AAD_POST_LOGOUT_URL',
    //   def: 'https://$firebaseProjectId.web.app/signed-out/',
    // );
    aadPostLogoutUrl  = _read('AAD_POST_LOGOUT_URL', def: '');
    microsoftTenantId = _read('MICROSOFT_TENANT_ID', def: '');

    // ---- App ----
    // Reads ALLOWED_EMAIL_DOMAIN from .env; fallback is mostly irrelevant now
    allowedEmailDomain = _read('ALLOWED_EMAIL_DOMAIN', def: '@student.csulb.edu');

    // Prefer explicit .env overrides; otherwise pick per platform.
    final envBaseIOS     = dotenv.maybeGet('API_BASE_IOS')?.trim();
    final envBaseAndroid = dotenv.maybeGet('API_BASE_ANDROID')?.trim();
    final envBaseGlobal  = dotenv.maybeGet('API_BASE')?.trim(); // optional fallback

    if (Platform.isAndroid && envBaseAndroid != null && envBaseAndroid.isNotEmpty) {
      apiBase = envBaseAndroid;
    } else if ((Platform.isIOS || Platform.isMacOS) && envBaseIOS != null && envBaseIOS.isNotEmpty) {
      apiBase = envBaseIOS;
    } else if (envBaseGlobal != null && envBaseGlobal.isNotEmpty) {
      apiBase = envBaseGlobal;
    } else if (kIsWeb) {
      apiBase = 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      apiBase = 'http://10.0.2.2:8000';
    } else {
      apiBase = 'http://127.0.0.1:8000'; // iOS simulator / macOS
    }

    debugPrint('✅ AppConfig: project=$firebaseProjectId apiBase=$apiBase '
        'tenant=$microsoftTenantId postLogout=$aadPostLogoutUrl');
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
