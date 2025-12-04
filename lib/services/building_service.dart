// lib/services/building_service.dart
import 'dart:convert';
import 'api_client.dart';
import '../config/app_config.dart';

class BuildingInfo {
  final String code;
  final String name;

  BuildingInfo({required this.code, required this.name});

  factory BuildingInfo.fromJson(Map<String, dynamic> json) {
    return BuildingInfo(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

class BuildingService {
  static List<BuildingInfo>? _cachedBuildings;

  static List<BuildingInfo>? get cachedBuildings => _cachedBuildings;

  static Future<List<BuildingInfo>> fetchBuildings({bool forceRefresh = false}) async {
    // --- Debug prints so we know EXACTLY what backend returns ---
    print(">>> Fetching buildings...");
    print(">>> URL = ${AppConfig.apiBase}/rooms/buildings");
    // -------------------------------------------------------------

    // Use cached result unless force-refresh requested
    if (!forceRefresh &&
        _cachedBuildings != null &&
        _cachedBuildings!.isNotEmpty) {
      print(">>> Using cached buildings (${_cachedBuildings!.length})");
      return _cachedBuildings!;
    }

    final resp = await apiGet('/rooms/buildings');

    // Debug network response
    print(">>> status = ${resp.statusCode}");
    print(">>> body = ${resp.body}");

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to load buildings: ${resp.statusCode} ${resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected buildings payload: $decoded');
    }

    // Expecting List<Map<String, dynamic>>
    final list = decoded
        .map((e) => BuildingInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    _cachedBuildings = list;
    print(">>> Parsed ${list.length} buildings successfully.");

    return list;
  }

}
