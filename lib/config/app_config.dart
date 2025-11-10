// lib/config/app_config.dart
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ---------- Auth0 ----------
  static late final String auth0Domain;
  static late final String auth0ClientId;
  static late final String callbackScheme;
  static String? apiAudience;
  static late final String allowedDomain;
  static late final String dbConnectionName;

  // ---------- Backend ----------
  static late final String baseUrl;

  // Initialize all configs
  static Future<void> init() async {
    // Load .env (make sure it's listed in pubspec.yaml assets)
    await dotenv.load();

    // ---------- Auth0 ----------
    auth0Domain      = dotenv.env['AUTH0_DOMAIN']!;
    auth0ClientId    = dotenv.env['AUTH0_CLIENT_ID']!;
    callbackScheme   = dotenv.env['CALLBACK_SCHEME'] ?? 'com.studybuddy';
    apiAudience      = dotenv.env['AUTH0_AUDIENCE'];
    allowedDomain    = dotenv.env['ALLOWED_DOMAIN'] ?? '@student.csulb.edu';
    dbConnectionName = dotenv.env['AUTH0_DB_CONNECTION'] ?? 'Username-Password-Authentication';

    // ---------- Backend ----------
    String? envBase = dotenv.env['BASE_URL'];
    if (Platform.isAndroid) {
      baseUrl = envBase ?? 'http://10.0.2.2:8000';
    } else if (Platform.isIOS) {
      baseUrl = envBase ?? 'http://127.0.0.1:8000';
    } else {
      baseUrl = envBase ?? 'http://127.0.0.1:8000';
    }
  }
}
