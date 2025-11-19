// lib/pages/findroom.dart
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'filter.dart';
import '../components/grad_button.dart';
import '../services/api.dart';
import '../models/room.dart';
import '../services/checkin_service.dart';

class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
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
    final now = TimeOfDay.now();
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

  void _checkIn(Room r) {
    CheckInService.instance.checkIn(room: r);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You checked into ${r.buildingCode}-${r.roomNumber} (${_fmt(context, r.start)}-${_fmt(context, r.end)})',
        ),
      ),
    );
    setState(() {}); // refresh current page so buttons update
  }

  void _checkOut(Room r) {
    if (CheckInService.instance.isCurrentRoom(r)) {
      CheckInService.instance.checkOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You checked out of ${r.buildingCode}-${r.roomNumber} (${_fmt(context, r.start)}-${_fmt(context, r.end)})',
          ),
        ),
      );
      setState(() {});
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

  String _formatAMPM(TimeOfDay t) {
    final dt = DateTime(2024, 1, 1, t.hour, t.minute);
    return DateFormat.jm().format(dt); // requires intl
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

                // Header row
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

                      final checkedIn = CheckInService.instance.checkedIn;

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

                              final parts = header.split('|');
                              final left = parts[0].trim();
                              final right =
                              (parts.length > 1) ? parts[1].trim() : '';

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
                                        right,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    ...slots.map((r) {
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

                                      final lockedButton = IgnorePointer(
                                        ignoring: isReported,
                                        child: Opacity(
                                          opacity: isReported ? 0.5 : 1.0,
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

                                      return Container(
                                        margin: const EdgeInsets.only(
                                            bottom: 10),
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
                                                if (checkedIn && isCurrent)
                                                  GradientButton(
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
                                                else
                                                  GradientButton(
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
