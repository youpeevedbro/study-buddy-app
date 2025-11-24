// lib/pages/findroom.dart
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'filter.dart';
import '../components/grad_button.dart';
import '../services/api.dart';
import '../models/room.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../services/timer_service.dart';

class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
  static const bool _debugFixed8am = false; // set to false for real current time

  /// Convert this room's date + end time into a DateTime.
  DateTime? _slotEndDateTime(Room r) {
    try {
      if (r.date.isEmpty || r.end.isEmpty) return null;

      final dateParts = r.date.split('-'); // "2025-11-24"
      if (dateParts.length != 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final timeParts = r.end.split(':');   // "08:30"
      if (timeParts.length != 2) return null;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  DateTime _now() {
    final real = DateTime.now();
    if (_debugFixed8am) {
      // pretend it's 8:00 am *today*
      return DateTime(real.year, real.month, real.day, 8, 59);
    }
    return real;
  }
  
  int _hhmmToMinutes(String hhmm) {
    if (hhmm.isEmpty) return -1;
    final parts = hhmm.split(':');
    if (parts.length != 2) return -1;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  bool _isSlotActiveNow(Room r) {
    // final now = DateTime.now(); // THIS IS THE REAL ONE
    final now = _now(); // THIS IS FOR DEBUGGING
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

    // Default: "Free Now" = buildingCode null, startTime = now, endTime = null
    // final now = TimeOfDay.now(); // THIS IS THE REAL ONE
    final now = _debugFixed8am ? const TimeOfDay(hour: 8, minute: 59) : TimeOfDay.now(); // THIS IS FOR DEBUGGING
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r.buildingCode}-${r.roomNumber} (${_fmt(context, r.start)}-${_fmt(context, r.end)}) reported as locked',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report room as locked: $e')),
      );
    }
  }

    Future<void> _checkIn(Room r) async {
      try {
        // 1) Update Firestore user doc
        await UserService.instance.checkInToRoom(r);

        // 2) Update local in-memory check-in state
        CheckInService.instance.checkIn(room: r);

        // 3) Start countdown timer for the remaining duration of this slot
        final end = _slotEndDateTime(r);
        final now = _now(); // uses your debug 8am override
        if (end != null) {
          final diff = end.difference(now);
          if (diff.inSeconds > 0) {
            TimerService.instance.start(diff);
          } else {
            // slot already ended or invalid -> make sure timer is stopped
            TimerService.instance.stop();
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You checked into ${r.buildingCode}-${r.roomNumber} '
              '(${_fmt(context, r.start)}-${_fmt(context, r.end)})',
            ),
          ),
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
          setState(() {}); // refresh buttons if needed
        }
      }
    }


  Future<void> _checkOut(Room r) async {
    if (!CheckInService.instance.isCurrentRoom(r)) return;

    try {
      // 1) Update Firestore user doc
      await UserService.instance.checkOutFromRoom();

      // 2) Update in-memory state + stop timer
      CheckInService.instance.checkOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You checked out of ${r.buildingCode}-${r.roomNumber} (${_fmt(context, r.start)}-${_fmt(context, r.end)})',
          ),
        ),
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
        setState(() {});
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

    final now = TimeOfDay.now();
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
    final dt = DateTime.now(); // always today
    return DateFormat('EEEE, MMM d, yyyy').format(dt);
  }

  String _formatAMPM(TimeOfDay t) {
    final dt = DateTime(2024, 1, 1, t.hour, t.minute);
    return DateFormat.jm().format(dt); // requires intl
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final checkedIn = CheckInService.instance.checkedIn;

    return Scaffold(
      backgroundColor: Colors.white,
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
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
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
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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

                // GOLD BACKGROUND CONTAINER
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFADA7A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(25),
                      bottom: Radius.circular(25),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
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

                      // Group by "{buildingCode}-{roomNumber} | date"
                      final Map<String, List<Room>> grouped = SplayTreeMap();
                      for (final r in rooms) {
                        final key =
                            '${r.buildingCode}-${r.roomNumber} | ${r.date}';
                        grouped.putIfAbsent(key, () => []).add(r);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: grouped.length,
                            itemBuilder: (context, i) {
                              final entry = grouped.entries.elementAt(i);
                              final header = entry.key;
                              final slots = entry.value;

                              // Left = room label (e.g. "ECS-407")
                              final parts = header.split('|');
                              final left = parts[0].trim();

                              // Header shows first slot's time range instead of the date
                              String headerTimeRange = '';
                              if (slots.isNotEmpty) {
                                final firstSlot = slots.first;
                                headerTimeRange =
                                    '${_fmt(context, firstSlot.start)} - ${_fmt(context, firstSlot.end)}';
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCF6DB),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  childrenPadding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                    top: 8,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          left,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        headerTimeRange,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    ...slots.map((r) {
                                      final isActiveNow = _isSlotActiveNow(r);
                                      final isCurrent =
                                          CheckInService.instance
                                              .isCurrentRoom(r);
                                      final key = _slotKey(r);

                                      final isReported = r.userHasReported ||
                                          _reportedSlots.contains(key);

                                      final reportCount =
                                          _slotReportCounts[key] ??
                                              r.lockedReports;
                                      final hasAnyReports =
                                          reportCount > 0;
                                      final reportLabel =
                                          '$reportCount Report${reportCount == 1 ? '' : 's'}';

                                      // Locked button disabled if already reported OR slot not active
                                      final shouldDisableLocked =
                                          isReported || !isActiveNow;

                                      final lockedButton = IgnorePointer(
                                        ignoring: shouldDisableLocked,
                                        child: Opacity(
                                          opacity:
                                              shouldDisableLocked ? 0.4 : 1.0,
                                          child: GradientButton(
                                            height: 35,
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            onPressed: () =>
                                                _reportLocked(r),
                                            child: const Text(
                                              'Locked',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );

                                      // Check-in / Check-out disabled if slot not active
                                      final checkInOutButton = IgnorePointer(
                                        ignoring: !isActiveNow,
                                        child: Opacity(
                                          opacity: !isActiveNow ? 0.4 : 1.0,
                                          child: checkedIn && isCurrent
                                              ? GradientButton(
                                                  height: 35,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  onPressed: () =>
                                                      _checkOut(r),
                                                  child: const Text(
                                                    'Check-out',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16.0,
                                                    ),
                                                  ),
                                                )
                                              : GradientButton(
                                                  height: 35,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  onPressed: () =>
                                                      _checkIn(r),
                                                  child: const Text(
                                                    'Check-in',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16.0,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      );

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 3,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_fmt(context, r.start)} - ${_fmt(context, r.end)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceEvenly,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Column(
                                                  children: [
                                                    lockedButton,
                                                    if (hasAnyReports)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                top: 4.0),
                                                        child: Text(
                                                          reportLabel,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.red,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                checkInOutButton,
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                onPressed: (_prevTokens.length > 1)
                                    ? _goPrev
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('Previous'),
                              ),
                              OutlinedButton.icon(
                                onPressed: (_nextToken != null)
                                    ? _goNext
                                    : null,
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
    );
  }
}
