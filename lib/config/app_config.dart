// lib/config/app_config.dart
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

  // URL Firebase uses to complete OAuth flows (used for AAD post-logout redirect)
  static late final String firebaseHandlerUrl;

  // === Microsoft / Entra ===
  static late final String microsoftTenantId; // e.g. d175679b-...-... (can be empty)

  // === App settings ===
  static late final String allowedEmailDomain; // single or comma separated (server enforces list)
  static late final String apiBase;            // FastAPI backend base URL

  /// Initialize configuration from .env (with safe defaults)
  static void init() {
    firebaseProjectId      = _read('FIREBASE_PROJECT_ID', def: 'studybuddy-e8dba');
    firebaseStorageBucket  = _read('FIREBASE_STORAGE_BUCKET', def: 'studybuddy-e8dba.firebasestorage.app');
    firebaseSenderId       = _read('FIREBASE_SENDER_ID', def: '157338247439');
    firebaseAndroidAppId   = _read('FIREBASE_ANDROID_APP_ID', def: '');
    firebaseIosAppId       = _read('FIREBASE_IOS_APP_ID', def: '');

    // If you prefer a custom value, expose FIREBASE_HANDLER_URL in .env
    firebaseHandlerUrl     = _read(
      'FIREBASE_HANDLER_URL',
      def: 'https://$firebaseProjectId.firebaseapp.com/__/auth/handler',
    );

    microsoftTenantId      = _read('MICROSOFT_TENANT_ID', def: '');

    allowedEmailDomain     = _read('ALLOWED_EMAIL_DOMAIN', def: '@csulb.edu');

    // Prefer explicit .env override if present
    final envBase = dotenv.maybeGet('API_BASE')?.trim();
    if (envBase != null && envBase.isNotEmpty) {
      apiBase = envBase;
    } else {
      // Choose a good default per platform
      if (kIsWeb) {
        apiBase = 'http://localhost:8000';
      } else if (Platform.isAndroid) {
        apiBase = 'http://10.0.2.2:8000'; // Android emulator -> host machine
      } else {
        // iOS simulator / desktop
        apiBase = 'http://localhost:8000';
      }
    }

    debugPrint(
      '✅ AppConfig initialized: domain=$allowedEmailDomain, '
          'project=$firebaseProjectId, apiBase=$apiBase, tenant=$microsoftTenantId',
    );
  }

  /// Safe reader with default fallback
  static String _read(String key, {String def = ''}) {
    final v = dotenv.maybeGet(key)?.trim();
    if (v == null || v.isEmpty) {
      debugPrint('⚠️  .env missing $key — using default "$def"');
      return def;
    }
    return v;
  }

  // --- Backwards-compat alias so existing code keeps compiling ---
  static String get allowedDomain => allowedEmailDomain;
}
