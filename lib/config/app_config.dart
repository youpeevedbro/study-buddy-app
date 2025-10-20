// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static late final String auth0Domain;
  static late final String auth0ClientId;
  static late final String callbackScheme;
  static String? apiAudience;
  static late final String allowedDomain;
  static late final String dbConnectionName;

  static void init() {
    auth0Domain      = dotenv.env['AUTH0_DOMAIN']!;
    auth0ClientId    = dotenv.env['AUTH0_CLIENT_ID']!;
    callbackScheme   = dotenv.env['CALLBACK_SCHEME'] ?? 'com.studybuddy';
    apiAudience      = dotenv.env['AUTH0_AUDIENCE'];
    allowedDomain    = dotenv.env['ALLOWED_DOMAIN'] ?? '@student.csulb.edu';
    dbConnectionName = dotenv.env['AUTH0_DB_CONNECTION'] ?? 'Username-Password-Authentication';
  }
}
