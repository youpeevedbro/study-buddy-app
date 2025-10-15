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
    return FilterCriteria(
      buildingCode: json['building'],
      startTime: json['startTime'] != null
          ? TimeOfDay.fromDateTime(DateTime.parse(json['startTime']))
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay.fromDateTime(DateTime.parse(json['endTime']))
          : null,
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

  // Placeholder backend call
  Future<void> _applyFilters() async {
    final criteria = FilterCriteria(
      buildingCode: _selectedBuilding,
      startTime: startTime,
      endTime: endTime,
    );

    try {
      // TODO: Replace this with real backend or Python API call later
      print('Filter criteria: ${criteria.toJson()}');

      // Return to parent
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
      _selectedBuilding = null;
      startTime = null;
      endTime = null;
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
                    child: const Text("Clear All"),
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
              const Text("Time",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time != null ? time.format(context) : label,
                style: const TextStyle(fontSize: 14),
              ),
              const Icon(Icons.access_time, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
