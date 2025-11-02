// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/room.dart';

// class Api {
//   // Android emulator -> host machine:
//   // static const String base = 'http://10.0.2.2:8000';
//   static const String base = 'http://127.0.0.1:8000';
//   // iOS Simulator: 'http://localhost:8000'
//   // Real device: 'http://<YOUR-PC-LAN-IP>:8000'

//   static Future<List<Room>> listRooms({int limit = 200, String? building, String? date}) async {
//     final qp = <String, String>{'limit': '$limit'};
//     if (building?.isNotEmpty == true) qp['building'] = building!;
//     if (date?.isNotEmpty == true) qp['date'] = date!;

//     final uri = Uri.parse('$base/rooms').replace(queryParameters: qp);
//     final res = await http.get(uri);

//     if (res.statusCode != 200) {
//       throw Exception('Failed to load rooms: ${res.statusCode} ${res.body}');
//     }

//     final data = jsonDecode(res.body) as Map<String, dynamic>;
//     final items = (data['items'] as List).cast<Map<String, dynamic>>();
//     return items.map((m) => Room.fromJson(m)).toList(); // ← returns List<Room>
//   }
// }


import 'dart:convert';
import 'dart:io' show Platform; // for Platform.isAndroid / isIOS
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/room.dart';

class Api {
  // You can change this later to your LAN IP for real devices
  static const String _localHost = 'http://127.0.0.1:8000';
  static const String _androidEmu = 'http://10.0.2.2:8000';

  static String get base {
    // 1) Flutter web
    if (kIsWeb) return 'http://localhost:8000';

    // 2) iOS simulator → can talk to Mac directly
    if (Platform.isIOS) return _localHost;

    // 3) Android emulator → must use 10.0.2.2
    if (Platform.isAndroid) return _androidEmu;

    // 4) desktop / fallback
    return _localHost;
  }

  static Future<List<Room>> listRooms({int limit = 200, String? building, String? date}) async {
    final qp = <String, String>{'limit': '$limit'};
    if (building?.isNotEmpty == true) qp['building'] = building!;
    if (date?.isNotEmpty == true) qp['date'] = date!;

    final uri = Uri.parse('$base/rooms').replace(queryParameters: qp);
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load rooms: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((m) => Room.fromJson(m)).toList();
  }
}
