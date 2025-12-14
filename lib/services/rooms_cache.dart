// lib/services/rooms_cache.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/dev_config.dart';

class CachedResponse {
  final DateTime timestamp;
  final String body;

  CachedResponse({required this.timestamp, required this.body});
}

class RoomsCache {
  static const String _boxName = 'roomsCache';
  static const Duration defaultTtl = Duration(minutes: 3);

  static Future<Box> _box() async => Hive.openBox(_boxName);

  static String _key({
    required String uid,
    required int limit,
    String? pageToken,
    String? building,
    String? date,
  }) {
    return [
      "uid=$uid",
      "limit=$limit",
      "pageToken=${pageToken ?? ''}",
      "building=${building ?? ''}",
      "date=${date ?? ''}",
    ].join("|");
  }

  static Future<CachedResponse?> load({
    required String uid,
    required int limit,
    String? pageToken,
    String? building,
    String? date,
    Duration? ttl,
  }) async {
    final box = await _box();
    final key = _key(
      uid: uid,
      limit: limit,
      pageToken: pageToken,
      building: building,
      date: date,
    );

    final raw = box.get(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw as String);
      final ts = DateTime.parse(decoded["timestamp"]);
      final expiry = ttl ?? defaultTtl;

      if (DevConfig.now().difference(ts) > expiry) {
        await box.delete(key);
        return null;
      }

      return CachedResponse(
        timestamp: ts,
        body: decoded["body"] as String,
      );
    } catch (_) {
      await box.delete(key);
      return null;
    }
  }

  static Future<void> save({
    required String uid,
    required int limit,
    String? pageToken,
    String? building,
    String? date,
    required String body,
  }) async {
    final box = await _box();
    final key = _key(
      uid: uid,
      limit: limit,
      pageToken: pageToken,
      building: building,
      date: date,
    );

    final payload = jsonEncode({
      "timestamp": DevConfig.now().toIso8601String(),
      "body": body,
    });

    await box.put(key, payload);
  }

  static Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
