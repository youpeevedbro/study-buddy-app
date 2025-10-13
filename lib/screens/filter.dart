import 'package:flutter/material.dart';
import '../components/grad_button.dart';


//----------------------Backend Zone Helper---------------------
// Filter data model to pass between screens and backend
class FilterCriteria {
  final bool upperCampus;
  final bool lowerCampus;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<int> selectedFloors;

  FilterCriteria({
    required this.upperCampus,
    required this.lowerCampus,
    this.startTime,
    this.endTime,
    required this.selectedFloors,
  });

  // Convert to Map for backend API calls
  Map<String, dynamic> toJson() {
    return {
      'upperCampus': upperCampus,
      'lowerCampus': lowerCampus,
      'startTime': startTime?.format24Hour(),
      'endTime': endTime?.format24Hour(),
      'floors': selectedFloors,
    };
  }

  // Create from Map (for backend responses)
  factory FilterCriteria.fromJson(Map<String, dynamic> json) {
    return FilterCriteria(
      upperCampus: json['upperCampus'] ?? false,
      lowerCampus: json['lowerCampus'] ?? false,
      startTime: json['startTime'] != null ? TimeOfDay.fromDateTime(DateTime.parse(json['startTime'])) : null,
      endTime: json['endTime'] != null ? TimeOfDay.fromDateTime(DateTime.parse(json['endTime'])) : null,
      selectedFloors: List<int>.from(json['floors'] ?? []),
    );
  }
}

// Extension to format TimeOfDay for backend
extension TimeOfDayExtension on TimeOfDay {
  String format24Hour() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
//------------------Let's Continue with Front End----------------------

class FilterPage extends StatefulWidget {
  final FilterCriteria? initialFilters; // Allow passing existing filters
  
  const FilterPage({super.key, this.initialFilters});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  // Example state variables
  bool upperCampus = false;
  bool lowerCampus = false;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<int> selectedFloors = [];

  @override
  void initState() {
    super.initState();
    // Initialize with existing filters if provided
    if (widget.initialFilters != null) {
      upperCampus = widget.initialFilters!.upperCampus;
      lowerCampus = widget.initialFilters!.lowerCampus;
      startTime = widget.initialFilters!.startTime;
      endTime = widget.initialFilters!.endTime;
      selectedFloors = List.from(widget.initialFilters!.selectedFloors);
    }
  }

// ---------------------Backend Zone---------------------
  // TODO: Connect to backend service
  Future<void> _applyFilters() async {
    final criteria = FilterCriteria(
      upperCampus: upperCampus,
      lowerCampus: lowerCampus,
      startTime: startTime,
      endTime: endTime,
      selectedFloors: selectedFloors,
    );

    try {
      // TODO: Replace with actual backend call
      
      print('Filter criteria: ${criteria.toJson()}'); // Debug print
      
      // Return the filter criteria to parent screen
      Navigator.pop(context, criteria);
      
    } catch (e) {
      // TODO: Handle backend errors
      print('Filter error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying filters: $e')),
      );
    }
  }

  // Clear all filters - useful for backend reset
  void _clearFilters() {
    setState(() {
      upperCampus = false;
      lowerCampus = false;
      startTime = null;
      endTime = null;
      selectedFloors.clear();
    });
  }
// ----------------------Let's Continue with Front End----------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
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
            
            // Header row with title and clear button
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

            // --- Campus Level ---
            const Text("Campus Level",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              children: [
                _buildCampusChip("Upper Campus", upperCampus, (v) {
                  setState(() => upperCampus = v);
                }),
                const SizedBox(width: 10),
                _buildCampusChip("Lower Campus", lowerCampus, (v) {
                  setState(() => lowerCampus = v);
                }),
              ],
            ),
            const SizedBox(height: 20),

            // --- Time Selection ---
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
            const SizedBox(height: 20),

            // --- Floor Section ---
            const Text("Floor",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [1, 2, 3, 4, 5].map((floor) { 
                final selected = selectedFloors.contains(floor);
                return FilterChip(
                  label: Text('$floor'),
                  selected: selected,
                  selectedColor: theme.primaryColor,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        selectedFloors.add(floor);
                      } else {
                        selectedFloors.remove(floor);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            // --- Action Buttons ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
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
                  child: 
                  GradientButton(
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
    );
  }

  // ---------------- Helper Widgets ----------------

  Widget _buildCampusChip(
      String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFFADA7A),
      checkmarkColor: Colors.black,
      onSelected: onChanged,
    );
  }

  Widget _buildTimeField(String label, TimeOfDay? time, Function(TimeOfDay?) onTimePicked) {
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
