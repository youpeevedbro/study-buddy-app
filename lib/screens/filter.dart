import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../components/grad_button.dart';

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
  Map<String, String> _buildingList = {};
  String? _selectedBuilding;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? _timeError;    // 👈 NEW

  @override
  void initState() {
    super.initState();
    _loadBuildings();

    if (widget.initialFilters != null) {
      _selectedBuilding = widget.initialFilters!.buildingCode;
      startTime = widget.initialFilters!.startTime;
      endTime = widget.initialFilters!.endTime;
    }
  }

  // Load building list from JSON
  Future<void> _loadBuildings() async {
    try {
      final String response =
          await rootBundle.loadString('assets/building_codes.json');
      final data = json.decode(response) as Map<String, dynamic>;
      setState(() {
        _buildingList =
            data.map((key, value) => MapEntry(key, value.toString()));
      });
    } catch (e) {
      print('Error loading buildings: $e');
    }
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // Placeholder backend call
  // Placeholder backend call
  Future<void> _applyFilters() async {
    // 1) Validate time range if both set
    if (startTime != null && endTime != null) {
      final startMin = _toMinutes(startTime!);
      final endMin   = _toMinutes(endTime!);

      if (startMin >= endMin) {
        // Show inline error in the sheet
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
      buildingCode: _selectedBuilding,
      startTime: startTime,
      endTime: endTime,
      // overlap: _overlap,  // if/when you add it
    );

    try {
      print('Filter criteria: ${criteria.toJson()}');
      Navigator.pop(context, criteria);
    } catch (e) {
      print('Filter error: $e');
      // You *can* still use a SnackBar here since it’s a real error, not validation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying filters: $e')),
      );
    }
  }



  void _clearFilters() {
    setState(() {
      _selectedBuilding = null;

      // Reset to “free AT the current time”
      final now = TimeOfDay.now();
      startTime = now;
      endTime = null;

      // Clear any time validation error
      _timeError = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text("Reset"),
                  ),
                ],
              ),
              const Divider(),

              // Building Dropdown
              const Text("Building",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCF6DB),
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedBuilding,
                  hint: const Text("Select a building"),
                  underline: const SizedBox(),
                  items: _buildingList.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBuilding = value);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Time
              // Time
              const Text(
                "Free (at/between/until)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),

              if (_timeError != null)               // 👈 NEW
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
                      height: 43,
                      borderRadius: BorderRadius.circular(12.0),
                      onPressed: () => _applyFilters(),
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
    );
  }

  // ---------------- Helper ----------------
  Widget _buildTimeField(
    String label, TimeOfDay? time, Function(TimeOfDay?) onTimePicked) {
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
                      surface: Color(0xFFFCF6DB),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF6DB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              children: [
                // Label / time text
                Expanded(
                  child: Text(
                    time != null ? time.format(context) : label,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

                // If a time is set, show a small "X" to clear it
                if (time != null) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => onTimePicked(null),
                  ),
                  const SizedBox(width: 4),
                ],

                // Clock icon
                const Icon(Icons.access_time, size: 18),
              ],
            ),
          ),
        ),
      );
    }
}
