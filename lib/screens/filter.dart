// lib/pages/filter.dart
import 'package:flutter/material.dart';
import '../components/grad_button.dart';
import '../services/building_service.dart';

// ---------------------- Backend Zone Helper ---------------------
class FilterCriteria {
  final String? buildingCode;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  FilterCriteria({
    this.buildingCode,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'building': buildingCode,
      'startTime': startTime?.format24Hour(),
      'endTime': endTime?.format24Hour(),
    };
  }

  factory FilterCriteria.fromJson(Map<String, dynamic> json) {
    TimeOfDay? _parseHHMM(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }

    return FilterCriteria(
      buildingCode: json['building'] as String?,
      startTime: _parseHHMM(json['startTime'] as String?),
      endTime: _parseHHMM(json['endTime'] as String?),
    );
  }
}

// Time formatter helper
extension TimeOfDayExtension on TimeOfDay {
  String format24Hour() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ---------------------- UI Starts Here ----------------------
class FilterPage extends StatefulWidget {
  final FilterCriteria? initialFilters;
  const FilterPage({super.key, this.initialFilters});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  // Live buildings from backend
  List<BuildingInfo> _buildings = [];
  bool _loadingBuildings = true;
  String? _buildingsError;

  String? _selectedBuildingCode;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? _timeError; // time validation error

  @override
  void initState() {
    super.initState();

    // Use cached buildings if available for instant UI
    final cached = BuildingService.cachedBuildings;
    if (cached != null && cached.isNotEmpty) {
      _buildings = cached;
      _loadingBuildings = false;
    } else {
      _loadBuildings();
    }

    if (widget.initialFilters != null) {
      _selectedBuildingCode = widget.initialFilters!.buildingCode;
      startTime = widget.initialFilters!.startTime;
      endTime = widget.initialFilters!.endTime;
    }
  }

  Future<void> _loadBuildings() async {
    setState(() {
      _loadingBuildings = true;
      _buildingsError = null;
    });

    try {
      final buildings = await BuildingService.fetchBuildings();

      if (!mounted) return;

      setState(() {
        _buildings = buildings;
        _loadingBuildings = false;

        if (_selectedBuildingCode != null &&
            !_buildings.any((b) => b.code == _selectedBuildingCode)) {
          _selectedBuildingCode = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBuildings = false;
        _buildingsError = e.toString();
      });
    }
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _applyFilters() async {
    // 1) Validate time range if both set
    if (startTime != null && endTime != null) {
      final startMin = _toMinutes(startTime!);
      final endMin = _toMinutes(endTime!);

      if (startMin >= endMin) {
        setState(() {
          _timeError = 'End time must be after start time.';
        });
        return;
      }
    }

    // If we got here, times are fine → clear any old error
    setState(() {
      _timeError = null;
    });

    // 2) Build criteria as before
    final criteria = FilterCriteria(
      buildingCode: _selectedBuildingCode,
      startTime: startTime,
      endTime: endTime,
    );

    try {
      print('Filter criteria (rooms): ${criteria.toJson()}');
      Navigator.pop(context, criteria);
    } catch (e) {
      print('Filter error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying filters: $e')),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedBuildingCode = null;

      // Reset to “free AT the current time”
      final now = TimeOfDay.now();
      startTime = now;
      endTime = null;

      _timeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 10,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Filters",
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text("Reset"),
                    ),
                  ],
                ),
                const Divider(),

                // Building
                const Text(
                  "Building",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),

                _buildBuildingDropdown(),
                const SizedBox(height: 20),

                // Time
                const Text(
                  "Free (at/between/until)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),

                if (_timeError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      _timeError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    _buildTimeField("Start Time", startTime, (t) {
                      setState(() => startTime = t);
                    }),
                    const SizedBox(width: 10),
                    _buildTimeField("End Time", endTime, (t) {
                      setState(() => endTime = t);
                    }),
                ],
                ),

                const SizedBox(height: 30),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: GradientButton(
                        width: double.infinity,
                        height: 45,
                        borderRadius: BorderRadius.circular(12.0),
                        onPressed: _applyFilters,
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Helper widgets ----------------

  Widget _buildBuildingDropdown() {
    if (_loadingBuildings) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const LinearProgressIndicator(),
      );
    }

    if (_buildingsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load buildings.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton(
            onPressed: _loadBuildings,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8EB),
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedBuildingCode,
        hint: const Text("Select a building"),
        underline: const SizedBox(),
        items: _buildings
            .map(
              (b) => DropdownMenuItem<String>(
                value: b.code,
                child: Text(b.name),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() => _selectedBuildingCode = value);
        },
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay? time,
    Function(TimeOfDay?) onTimePicked,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ?? TimeOfDay.now(),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFE7C144),
                    surface: Color(0xFFF7F8EB),
                    onSurface: Colors.black,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) onTimePicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8EB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  time != null ? time.format(context) : label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (time != null) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => onTimePicked(null),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.access_time, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
