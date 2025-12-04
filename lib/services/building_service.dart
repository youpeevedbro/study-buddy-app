// lib/services/building_service.dart
import 'dart:convert';
import 'api_client.dart';

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
    if (!forceRefresh &&
        _cachedBuildings != null &&
        _cachedBuildings!.isNotEmpty) {
      return _cachedBuildings!;
    }

    final resp = await apiGet('/rooms/buildings');

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to load buildings: ${resp.statusCode} ${resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected buildings payload: $decoded');
    }

    final list = decoded
        .map((e) => BuildingInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    _cachedBuildings = list;
    return list;
  }
}
