class Room {
  final String id;
  final String buildingCode;
  final String roomNumber;
  final String start;
  final String end;
  final int lockedReports;

  Room({
    required this.id,
    required this.buildingCode,
    required this.roomNumber,
    required this.start,
    required this.end,
    required this.lockedReports,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
    id: j['id'] as String,
    buildingCode: (j['buildingCode'] ?? '') as String,
    roomNumber: (j['roomNumber'] ?? '').toString(),
    start: (j['start'] ?? '') as String,
    end: (j['end'] ?? '') as String,
    lockedReports: (j['lockedReports'] ?? 0) as int,
  );
}
