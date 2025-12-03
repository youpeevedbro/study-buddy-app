import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../components/grad_button.dart';
import 'package:intl/intl.dart';

// ---------------------- Backend Zone Helper ---------------------
class FilterCriteriaForGroup {
  final String? buildingCode;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  FilterCriteriaForGroup({
    this.buildingCode,
    required this.date,
    this.startTime,
    this.endTime,
  });

  

  Map<String, dynamic> toJson() {
    String _formatDate(DateTime d) {
      DateFormat formatted_date = DateFormat('yyyy-MM-dd');
      return formatted_date.format(d);
    }

    return {
      'building': buildingCode,
      'date': _formatDate(date),
      'startTime': startTime?.format24Hour(),
      'endTime': endTime?.format24Hour(),
    };
  }

  factory FilterCriteriaForGroup.fromJson(Map<String, dynamic> json) {
    TimeOfDay? _parseHHMM(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }

    DateTime _parseDate(String d) {
      DateFormat format = DateFormat("yyyy-MM-dd");
      return format.parse(d);
    }

    return FilterCriteriaForGroup(
      buildingCode: json['building'] as String?,
      date: _parseDate(json['date'] as String),
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
class FilterPageForGroup extends StatefulWidget {
  final FilterCriteriaForGroup? initialFilters;
  const FilterPageForGroup({super.key, this.initialFilters});

  @override
  State<FilterPageForGroup> createState() => _FilterPageForGroupState();
}

class _FilterPageForGroupState extends State<FilterPageForGroup> {
  Map<String, String> _buildingList = {};
  String? _selectedBuilding;
  late DateTime _selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? _timeError;    // 👈 NEW

  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBuildings();

    // Define allowed window: today -> 7 days from today (inclusive)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekOut = today.add(const Duration(days: 7));

    if (widget.initialFilters != null) {
      final d = widget.initialFilters!.date;
      // Clamp initialFilters date into [today, weekOut]
      if (d.isBefore(today)) {
        _selectedDate = today;
      } else if (d.isAfter(weekOut)) {
        _selectedDate = weekOut;
      } else {
        _selectedDate = d;
      }
    } else {
      _selectedDate = today;
    }

    _dateController.text = _formatDate(_selectedDate);
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
    final criteria = FilterCriteriaForGroup(
      buildingCode: _selectedBuilding,
      date: _selectedDate,
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

  String _formatDate(DateTime d) {
    DateFormat formatted_date = DateFormat('yyyy-MM-dd');
    return formatted_date.format(d);
  }

  Future<void> _selectDate(BuildContext context) async {
    // Allowed window: today -> 7 days from today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekOut = today.add(const Duration(days: 7));

    // Clamp the current selected date into the valid window
    DateTime initialDate = _selectedDate;
    if (initialDate.isBefore(today)) {
      initialDate = today;
    } else if (initialDate.isAfter(weekOut)) {
      initialDate = weekOut;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: weekOut,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked); // yyyy-MM-dd
      });
    }
  }



  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  return FractionallySizedBox(
    heightFactor: 0.7,
    child: Container(
      // 🔸 vertical gradient background
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF3D9), // same as my_studygroup.dart
            Color(0xFFFFE2B8),
          ],
        ),
      ),
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
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text("Reset"),
                  ),
                ],
              ),
              const Divider(),

              const Text("Date",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              // Date (Calendar)
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date (MM/DD/YYYY)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 15),

              // Building Dropdown
              const Text("Building",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

              const Text(
                "Free (at/between/until)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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

              // Buttons with shadows
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor:
                              Colors.white.withOpacity(0.9), // subtle fill
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
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
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
