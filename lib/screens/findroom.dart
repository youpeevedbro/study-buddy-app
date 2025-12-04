// lib/pages/findroom.dart
// import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'filter.dart';
// import '../components/grad_button.dart';
import '../services/api.dart';
import '../models/room.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../services/timer_service.dart';
import '../config/dev_config.dart';
import '../components/room_card.dart';

class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF81C784),
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  void _showLockedSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE57373),
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  /// Convert this room's date + end time into a DateTime.
  DateTime? _slotEndDateTime(Room r) {
    try {
      if (r.date.isEmpty || r.end.isEmpty) return null;

      final dateParts = r.date.split('-'); // "2025-11-24"
      if (dateParts.length != 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final timeParts = r.end.split(':'); // "08:30"
      if (timeParts.length != 2) return null;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  DateTime _now() => DevConfig.now();

  int _hhmmToMinutes(String hhmm) {
    if (hhmm.isEmpty) return -1;
    final parts = hhmm.split(':');
    if (parts.length != 2) return -1;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  bool _isSlotActiveNow(Room r) {
    final now = _now(); // uses DevConfig.now() (real or fake)
    final nowMin = now.hour * 60 + now.minute;

    final startMin = _hhmmToMinutes(r.start);
    final endMin = _hhmmToMinutes(r.end);

    if (startMin < 0 || endMin < 0) return false;

    // active if: start <= now < end
    return startMin <= nowMin && nowMin < endMin;
  }

  // --- Pagination state ---
  static const int _pageSize = 50;
  String? _nextToken;
  final List<String?> _prevTokens = <String?>[null]; // first page uses null cursor

  // --- Filters from FilterPage ---
  FilterCriteria? _currentFilter;

  // --- Future for the current page ---
  Future<RoomsPage>? _futurePage;

  // --- Local "reported once per user session" state ---
  final Set<String> _reportedSlots = <String>{};
  final Map<String, int> _slotReportCounts = <String, int>{};

  @override
  void initState() {
    super.initState();

    final now = TimeOfDay.fromDateTime(DevConfig.now());
    _currentFilter = FilterCriteria(
      buildingCode: null,
      startTime: now,
      endTime: null,
    );

    _futurePage = _fetchPage(limit: _pageSize, pageToken: null);
    CheckInService.instance.addListener(_onCheckinChange);
  }

  void _onCheckinChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    CheckInService.instance.removeListener(_onCheckinChange);
    super.dispose();
  }

  // -------- Helpers to read values from FilterCriteria safely --------
  String? _buildingFrom(FilterCriteria? f) {
    if (f == null) return null;
    try {
      final v = (f as dynamic).building as String?;
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (f as dynamic).buildingCode as String?;
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  String? _dateFrom(FilterCriteria? f) {
    if (f == null) return null;
    try {
      final v = (f as dynamic).date;
      if (v is String && v.isNotEmpty) return v;
      if (v is DateTime) return v.toIso8601String().split('T').first;
    } catch (_) {}
    try {
      final v = (f as dynamic).selectedDate;
      if (v is String && v.isNotEmpty) return v;
      if (v is DateTime) return v.toIso8601String().split('T').first;
    } catch (_) {}
    return null;
  }

  // Unique key for a specific time slot (room + date + time)
  String _slotKey(Room r) =>
      '${r.buildingCode}-${r.roomNumber}|${r.date}|${r.start}-${r.end}';

  // Pretty formatter "HH:mm" -> localized time (e.g. "3:00 PM")
  String _fmt(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final dt = DateTime(2025, 1, 1, hour, minute);
    return TimeOfDay.fromDateTime(dt).format(context);
  }

  // Core fetch with current filters
  Future<RoomsPage> _fetchPage({
    required int limit,
    String? pageToken,
  }) async {
    try {
      final b = _buildingFrom(_currentFilter);
      final d = _dateFrom(_currentFilter);
      final s = _currentFilter?.startTime?.format24Hour();
      final e = _currentFilter?.endTime?.format24Hour();

      final page = await Api.listRoomsPage(
        limit: limit,
        pageToken: pageToken,
        building: b,
        startTime: s,
        endTime: e,
        date: d,
      );

      return page;
    } catch (e) {
      // ignore: avoid_print
      print(">>> API ERROR (listRoomsPage): $e");
      rethrow;
    }
  }

  // Reload from first page (after setting/changing filters or on retry)
  void _reload() {
    _nextToken = null;
    _prevTokens
      ..clear()
      ..add(null);
    setState(() {
      _futurePage = _fetchPage(limit: _pageSize, pageToken: null);
    });
  }

  // UI: open filter bottom sheet
  void _openFilterPopup() async {
    final result = await showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => FilterPage(initialFilters: _currentFilter),
    );

    if (result != null) {
      setState(() => _currentFilter = result);
      _reload();
    }
  }

  // Actions
  Future<void> _reportLocked(Room r) async {
    final key = _slotKey(r);
    if (_reportedSlots.contains(key)) return; // already reported once this session

    try {
      final newCount = await Api.reportRoomLocked(r.id);

      setState(() {
        _reportedSlots.add(key);
        _slotReportCounts[key] = newCount;
      });

      _showLockedSnack(
        '${r.buildingCode}-${r.roomNumber} (${_fmt(context, r.start)}-${_fmt(context, r.end)}) reported as locked',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report room as locked: $e')),
      );
    }
  }

  Future<void> _checkIn(Room r) async {
    try {
      await UserService.instance.checkInToRoom(r);
      r.currentCheckins = (r.currentCheckins) + 1;
      CheckInService.instance.checkIn(room: r);

      final end = _slotEndDateTime(r);
      final now = _now();
      if (end != null) {
        final diff = end.difference(now);
        if (diff.inSeconds > 0) {
          TimerService.instance.start(diff);
        } else {
          TimerService.instance.stop();
        }
      }

      if (!mounted) return;
      _showSuccessSnack(
        'You checked into ${r.buildingCode}-${r.roomNumber} '
        '(${_fmt(context, r.start)}-${_fmt(context, r.end)})',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check in: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _checkOut(Room r) async {
    if (!CheckInService.instance.isCurrentRoom(r)) return;

    try {
      // 1) Update Firestore user doc
      await UserService.instance.checkOutFromRoom();

      // 2) Optimistic decrement of local count
      if (r.currentCheckins > 0) {
        r.currentCheckins = r.currentCheckins - 1;
      }

      // 3) Update in-memory state + stop timer
      CheckInService.instance.checkOut();

      if (!mounted) return;
      _showSuccessSnack(
        'You checked out of ${r.buildingCode}-${r.roomNumber} (${_fmt(context, r.start)}-${_fmt(context, r.end)})',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check out: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {}); // refresh buttons + counts
      }
    }
  }

  // Pagination controls
  void _goNext() {
    if (_nextToken == null) return;
    _prevTokens.add(_nextToken);
    setState(() {
      _futurePage = _fetchPage(limit: _pageSize, pageToken: _nextToken);
    });
  }

  void _goPrev() {
    if (_prevTokens.length <= 1) return; // first page already
    _prevTokens.removeLast();
    final prev = _prevTokens.last; // may be null (first page)
    setState(() {
      _futurePage = _fetchPage(limit: _pageSize, pageToken: prev);
    });
  }

  String _currentFilterLabel() {
    final f = _currentFilter;

    if (f == null) return "Free Now";

    final noBuilding =
        (f.buildingCode == null || f.buildingCode!.isEmpty);
    final noStart = (f.startTime == null);
    final noEnd = (f.endTime == null);

    if (noBuilding && noStart && noEnd) {
      return "Availability Schedule";
    }

    final now = TimeOfDay.fromDateTime(DevConfig.now());
    final defaultStart = f.startTime != null &&
        f.endTime == null &&
        now.hour == f.startTime!.hour &&
        now.minute == f.startTime!.minute;

    if (defaultStart) {
      final formatted = _formatAMPM(now);
      return "Free Now ($formatted)";
    }

    if (f.startTime != null && f.endTime == null) {
      return "Free At ${_formatAMPM(f.startTime!)}";
    }

    if (f.startTime == null && f.endTime != null) {
      return "Free Until ${_formatAMPM(f.endTime!)}";
    }

    if (f.startTime != null && f.endTime != null) {
      return "Free Between ${_formatAMPM(f.startTime!)} – ${_formatAMPM(f.endTime!)}";
    }

    return "Available Rooms";
  }

  String _currentDateLabel() {
    final dt = DevConfig.now(); // always today
    return DateFormat('EEEE, MMM d, yyyy').format(dt);
  }

  String _formatAMPM(TimeOfDay t) {
    final dt = DateTime(2024, 1, 1, t.hour, t.minute);
    return DateFormat.jm().format(dt); // requires intl
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    final checkedIn = CheckInService.instance.checkedIn;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF7F8EB), // lighter tint
            Color(0xFFF1F3E0), // requested base color
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: 100,
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2F3E2F),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header row + date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Find Room",
                      style: TextStyle(
                        fontFamily: 'SuperLobster',
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A3024),
                      ),
                    ),
                    IconButton(
                      onPressed: _openFilterPopup,
                      icon: const Icon(Icons.filter_list, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentDateLabel(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Divider(color: Colors.black, thickness: 2),
                const SizedBox(height: 10),

                // Filter summary label
                Text(
                  _currentFilterLabel(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // Flatten: remove inner card background; render directly on gradient
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FutureBuilder<RoomsPage>(
                    future: _futurePage,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Error: ${snap.error}',
                              style: const TextStyle(height: 1.3),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _reload,
                              child: const Text('Retry'),
                            ),
                          ],
                        );
                      }
                      final page = snap.data;
                      final rooms = page?.items ?? [];
                      _nextToken = page?.nextPageToken;

                      if (rooms.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('No rooms found')),
                        );
                      }

                      // Render via RoomSlotCard component
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final r = rooms[index];

                              final isActiveNow = _isSlotActiveNow(r);
                              final isCurrent = CheckInService.instance.isCurrentRoom(r);
                              final key = _slotKey(r);

                              final isReported = r.userHasReported || _reportedSlots.contains(key);
                              final reportCount = _slotReportCounts[key] ?? r.lockedReports;

                              final canReportLocked = isActiveNow && !isReported;
                              final canCheckInOut = isActiveNow;
                              final showCheckOut = checkedIn && isCurrent;

                              return RoomSlotCard(
                                roomLabel: '${r.buildingCode}-${r.roomNumber}',
                                timeRangeLabel: '${_fmt(context, r.start)} - ${_fmt(context, r.end)}',
                                isActiveNow: isActiveNow,
                                checkinsCount: r.currentCheckins,
                                reportCount: reportCount,
                                canReportLocked: canReportLocked,
                                canCheckInOut: canCheckInOut,
                                showCheckOut: showCheckOut,
                                onReportLocked: () => _reportLocked(r),
                                onCheckIn: () => _checkIn(r),
                                onCheckOut: () => _checkOut(r),
                              );
                            },
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                onPressed: (_prevTokens.length > 1) ? _goPrev : null,
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('Previous'),
                              ),
                              OutlinedButton.icon(
                                onPressed: (_nextToken != null) ? _goNext : null,
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('Next'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}