import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const auth0Domain      = 'dev-qcz5hdonm0stlozz.us.auth0.com';
const auth0ClientId    = 'yE6ebH53vppjcmhAfqaEOMRsCKivuylT';
const callbackScheme   = 'com.studybuddy';
const dbConnectionName = 'Username-Password-Authentication';
const apiAudience      = null;

const allowedDomain = '@student.csulb.edu';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth0  = Auth0(auth0Domain, auth0ClientId);
  final _secure = const FlutterSecureStorage();

  String? _accessToken;
  String? _idToken;
  String? _refreshToken;

  Future<void> login() async {
    final creds = await _auth0
        .webAuthentication(scheme: callbackScheme)
        .login(audience: apiAudience);
    await _store(creds);
  }

  Future<void> signup() async {
    final creds = await _auth0
        .webAuthentication(scheme: callbackScheme)
        .login(audience: apiAudience, parameters: const {'screen_hint': 'signup'});
    await _store(creds);
  }

  Future<void> logout() async {
    final returnTo =
        '$callbackScheme://$auth0Domain/android/com.example.study_buddy/callback';

    await _secure.deleteAll();
    _accessToken = _idToken = _refreshToken = null;

    try {
      await _auth0.webAuthentication(scheme: callbackScheme).logout(returnTo: returnTo);
    } catch (_) {}
  }



  Future<void> sendPasswordResetEmail(String email) async {
    final lower = email.trim().toLowerCase();
    if (!lower.endsWith(allowedDomain)) {
      throw Exception('Please use your $allowedDomain email.');
    }
    final uri = Uri.https(auth0Domain, '/dbconnections/change_password');
    final res = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'client_id': auth0ClientId,
        'email': lower,
        'connection': dbConnectionName,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('Reset email failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> _store(Credentials c) async {
    _accessToken  = c.accessToken;
    _idToken      = c.idToken;
    _refreshToken = c.refreshToken;
    await _secure.write(key: 'access_token', value: _accessToken);
    await _secure.write(key: 'id_token', value: _idToken);
    if (_refreshToken != null) {
      await _secure.write(key: 'refresh_token', value: _refreshToken);
    }
  }

  Future<bool> isLoggedIn() async {
    // refresh cached tokens from storage
    if (_idToken == null) {
      _idToken = await _secure.read(key: 'id_token');
    }

    final claims = _decodeJwt(_idToken);
    if (claims == null) return false;

    final exp = claims['exp'];
    if (exp is int) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp > now;
    }
    return false;
  }

  Map<String, dynamic>? _decodeJwt(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
