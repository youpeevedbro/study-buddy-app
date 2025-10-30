import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';

class Api {
  // Android emulator -> host machine:
  static const String base = 'http://10.0.2.2:8000';
  // iOS Simulator: 'http://localhost:8000'
  // Real device: 'http://<YOUR-PC-LAN-IP>:8000'

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
    return items.map((m) => Room.fromJson(m)).toList(); // ← returns List<Room>
  }
}
