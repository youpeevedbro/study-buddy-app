// lib/models/room.dart

class Room {
  final String id;
  final String buildingCode;
  final String roomNumber;
  final String date;      // can be "" if missing
  final String start;     // can be "" if missing
  final String end;       // can be "" if missing
  final int lockedReports;
  final bool userHasReported; // did THIS user already report this slot?
  int currentCheckins;

  Room({
    required this.id,
    required this.buildingCode,
    required this.roomNumber,
    required this.date,
    required this.start,
    required this.end,
    required this.lockedReports,
    this.userHasReported = false,
    required this.currentCheckins,
  });

  factory Room.fromJson(Map<String, dynamic> j) {
    final lockedRaw = j['lockedReports'];
    final userReportedRaw = j['userHasReported'];

    final lockedReports = (lockedRaw is int)
        ? lockedRaw
        : int.tryParse((lockedRaw ?? '0').toString()) ?? 0;

    bool userHasReported;
    if (userReportedRaw is bool) {
      userHasReported = userReportedRaw;
    } else if (userReportedRaw is int) {
      userHasReported = userReportedRaw != 0;
    } else {
      userHasReported =
      (userReportedRaw?.toString().toLowerCase() == 'true');
    }

    return Room(
      id: (j['id'] ?? '').toString(),
      buildingCode: (j['buildingCode'] ?? '').toString(),
      roomNumber: (j['roomNumber'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      start: (j['start'] ?? '').toString(),
      end: (j['end'] ?? '').toString(),
      lockedReports: lockedReports,
      userHasReported: userHasReported,
      currentCheckins: (j['currentCheckins'] is int)                     // 👈 NEW
        ? j['currentCheckins'] as int
        : int.tryParse(j['currentCheckins']?.toString() ?? '0') ?? 0
    );
  }
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
