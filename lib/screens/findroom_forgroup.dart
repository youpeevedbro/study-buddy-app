// lib/pages/findroom_forgroup.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'filter_forgroup.dart';
import '../components/room_card.dart';
import '../services/api.dart';
import '../models/room.dart';
import '../models/group.dart';
import '../services/building_service.dart';
import '../config/dev_config.dart';

class FindRoomForGroupPage extends StatefulWidget {
  final SelectedGroupFields initialFilters;
  const FindRoomForGroupPage({super.key, required this.initialFilters});

  @override
  State<FindRoomForGroupPage> createState() => _FindRoomForGroupPageState();
}

class _FindRoomForGroupPageState extends State<FindRoomForGroupPage> {
  // --- Pagination state ---
  static const int _pageSize = 50;
  String? _nextToken;
  final List<String?> _prevTokens = <String?>[null]; // first page uses null cursor

  // --- Filters from FilterPageForGroup ---
  FilterCriteriaForGroup? _currentFilter;
  
  // --- Future for the current page ---
  Future<RoomsPage>? _futurePage;

  // --- Building code -> name map ---
  final Map<String, String> _buildingNameByCode = {};

  @override
  void initState() {
    super.initState();

    // Initialize filters from incoming group flow
    final DateTime initialDate = widget.initialFilters.date ?? DevConfig.now();
    _currentFilter = FilterCriteriaForGroup(
      buildingCode: widget.initialFilters.building,
      date: initialDate,
      startTime: widget.initialFilters.startTime,
      endTime: widget.initialFilters.endTime,
    );

    // Start first page fetch
    _futurePage = _fetchPage(limit: _pageSize, pageToken: null);

    // Load buildings and build mapping
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    try {
      final list = await BuildingService.fetchBuildings();
      final map = <String, String>{};
      for (final b in list) {
        map[b.code] = b.name;
      }
      if (!mounted) return;
      setState(() {
        _buildingNameByCode
          ..clear()
          ..addAll(map);
      });
    } catch (e) {
      // ignore: avoid_print
      print('>>> Failed to load buildings: $e');
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

  // -------- Helpers to read values from FilterCriteriaForGroup safely --------
  String? _buildingFrom(FilterCriteriaForGroup? f) {
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

  String? _dateFrom(FilterCriteriaForGroup? f) {
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

  // Pretty formatter "HH:mm" -> localized time (e.g. "3:00 PM")
  String _fmt(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2025, 1, 1, hour, minute);
    return TimeOfDay.fromDateTime(dt).format(context);
  }

  // Date formatter for labels
  String _formatDate(DateTime d) {
    return DateFormat('EEEE, MMM d, yyyy').format(d);
  }

  // Convert "HH:mm" -> TimeOfDay
  TimeOfDay _hhmmToTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 0;
    final m = int.tryParse(parts.elementAt(1)) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  // For group selection, allow adding any slot; if you want to disable past slots,
  // treat a slot as closed when end time is earlier than now on the selected date.
  bool _isSlotClosed(Room r) {
    try {
      final dateStr = _dateFrom(_currentFilter);
      if (dateStr == null || dateStr.isEmpty) return false;
      final parts = dateStr.split('-');
      if (parts.length != 3) return false;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final endParts = r.end.split(':');
      if (endParts.length != 2) return false;
      final eh = int.parse(endParts[0]);
      final em = int.parse(endParts[1]);
      final endDt = DateTime(year, month, day, eh, em);
      return DevConfig.now().isAfter(endDt);
    } catch (_) {
      return false;
    }
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

  // UI: open filter bottom sheet
  void _openFilterPopup() async {
    final result = await showModalBottomSheet<FilterCriteriaForGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => FilterPageForGroup(initialFilters: _currentFilter),
    );

    if (result != null) {
      setState(() {
        _currentFilter = result;
      });
      _reload();
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

    final noBuilding = (f.buildingCode == null || f.buildingCode!.isEmpty);
    final noStart = (f.startTime == null);
    final noEnd = (f.endTime == null);

    if (noBuilding && noStart && noEnd) {
      return "Availability Schedule for ${_formatDate(f.date)}";
    }

    final now = TimeOfDay.now();
    final defaultStart = f.startTime != null &&
        f.endTime == null &&
        now.hour == f.startTime!.hour &&
        now.minute == f.startTime!.minute;

    if (defaultStart) {
      final formatted = _formatAMPM(now);
      return "Free at ($formatted) on ${_formatDate(f.date)}";
    }

    if (f.startTime != null && f.endTime == null) {
      return "Free At ${_formatAMPM(f.startTime!)} on ${_formatDate(f.date)}";
    }

    if (f.startTime == null && f.endTime != null) {
      return "Free Until ${_formatAMPM(f.endTime!)} on ${_formatDate(f.date)}";
    }

    if (f.startTime != null && f.endTime != null) {
      return "Free Between ${_formatAMPM(f.startTime!)} – ${_formatAMPM(f.endTime!)} on ${_formatDate(f.date)}";
    }

    return "Available Rooms";
  }

  String _formatAMPM(TimeOfDay t) {
    final dt = DateTime(2024, 1, 1, t.hour, t.minute);
    return DateFormat.jm().format(dt); // requires intl
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF7F8EB),
            Color(0xFFF1F3E0),
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
        foregroundColor: Colors.black,
        elevation: 0,
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
                      "Find a time slot",
                      style: TextStyle(
                        fontFamily: 'SuperLobster',
                        fontSize: 30,
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

                // Flatten: render directly on gradient like FindRoom
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

                      // Flatten list: render each slot as a standalone RoomSlotCard
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rooms.length,
                            itemBuilder: (context, i) {
                              final r = rooms[i];
                              final isClosed = _isSlotClosed(r);

                              Widget card = RoomSlotCard(
                                roomLabel: '${r.buildingCode}-${r.roomNumber}',
                                buildingName: _buildingNameByCode[r.buildingCode],
                                timeRangeLabel: '${_fmt(context, r.start)} - ${_fmt(context, r.end)}',
                                isActiveNow: !isClosed,
                                checkinsCount: r.currentCheckins,
                                reportCount: r.lockedReports,
                                canReportLocked: false,
                                canCheckInOut: false,
                                showCheckOut: false,
                                onReportLocked: () {},
                                onCheckIn: () {},
                                onCheckOut: () {},
                                groupMode: true,
                                onAdd: isClosed
                                    ? null
                                    : () {
                                        final fields = SelectedGroupFields(
                                          date: _currentFilter!.date,
                                          building: r.buildingCode,
                                          roomNumber: r.roomNumber,
                                          startTime: _hhmmToTimeOfDay(r.start),
                                          endTime: _hhmmToTimeOfDay(r.end),
                                          availabilitySlotDoc: r.id,
                                        );
                                        Navigator.pop(context, fields);
                                      },
                              );

                              if (isClosed) {
                                card = IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.45,
                                    child: card,
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: card,
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
      ),
    );
  }
}
