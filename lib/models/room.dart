// lib/models/room.dart

class Room {
  final String id;
  final String buildingCode;
  final String roomNumber;
  final String date;      // can be "" if missing
  final String start;     // can be "" if missing
  final String end;       // can be "" if missing
  final int lockedReports;

  Room({
    required this.id,
    required this.buildingCode,
    required this.roomNumber,
    required this.date,
    required this.start,
    required this.end,
    required this.lockedReports,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
    id: (j['id'] ?? '').toString(),
    buildingCode: (j['buildingCode'] ?? '').toString(),
    roomNumber: (j['roomNumber'] ?? '').toString(),
    date: (j['date'] ?? '').toString(),
    start: (j['start'] ?? '').toString(),
    end: (j['end'] ?? '').toString(),
    lockedReports: (j['lockedReports'] is int)
        ? j['lockedReports'] as int
        : int.tryParse((j['lockedReports'] ?? '0').toString()) ?? 0,
  );
}

class RoomsPage {
  final List<Room> items;
  final String? nextPageToken;

  RoomsPage({required this.items, required this.nextPageToken});

  factory RoomsPage.fromJson(Map<String, dynamic> j) => RoomsPage(
    items: (j['items'] as List<dynamic>? ?? const [])
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextPageToken: j['nextPageToken'] as String?,
  );
}
