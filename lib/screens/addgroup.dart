import 'package:flutter/material.dart';
import '../components/grad_button.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AddGroupPage extends StatefulWidget {
  const AddGroupPage({super.key});

  @override
  State<AddGroupPage> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends State<AddGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  bool _submitting = false;

  String get _apiBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // Android emulator localhost
    return 'http://localhost:8000'; // iOS simulator/desktop
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final uri = Uri.parse('$_apiBaseUrl/groups/create');
      final body = jsonEncode({
        "name": _groupNameController.text.trim(),
        "location": _locationController.text.trim(),
        "date": _dateController.text.trim(),
        "starttime": _startTimeController.text.trim(),
        "endtime": _endTimeController.text.trim(),
        "max_members": int.tryParse(_maxController.text.trim()) ?? 0,
        "creator_id": "user_123",
      });

      final resp = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (!mounted) return; // widget may have been popped while awaiting
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yay! Your new group is created!")),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${resp.statusCode} ${resp.body}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Helpers to parse/format "hh:mm AM/PM"
  DateTime? _parseTime(String value) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(value.trim());
    if (m == null) return null;
    int hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final period = m.group(3)!;
    if (period.toUpperCase() == 'PM' && hour != 12) hour += 12;
    if (period.toUpperCase() == 'AM' && hour == 12) hour = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _formatTime(DateTime dt) {
    final tod = TimeOfDay.fromDateTime(dt);
    final hour = tod.hourOfPeriod.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Controller-aware Cupertino time picker
  void _showCupertinoTimePickerFor(TextEditingController controller) {
    DateTime initial = _parseTime(controller.text) ?? DateTime.now();
    DateTime temp = initial;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('Done'),
                    onPressed: () {
                      setState(() {
                        controller.text = _formatTime(temp);
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime: initial,
                onDateTimeChanged: (dt) {
                  temp = dt; // commit on Done
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Date picker
  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              // Group Name
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: "Group Name"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter a group name" : null,
              ),
              const SizedBox(height: 15),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                    labelText: "Location (Building - Room)"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter a location" : null,
              ),
              const SizedBox(height: 15),

              // Date (Calendar)
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Date (MM/DD/YYYY)",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 15),

              // Start Time
              TextFormField(
                controller: _startTimeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Start Time",
                  suffixIcon: Icon(Icons.access_time),
                ),
                onTap: () => _showCupertinoTimePickerFor(_startTimeController),
              ),
              const SizedBox(height: 15),

              // End Time
              TextFormField(
                controller: _endTimeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "End Time",
                  suffixIcon: Icon(Icons.access_time),
                ),
                onTap: () => _showCupertinoTimePickerFor(_endTimeController),
              ),
              const SizedBox(height: 15),

              // Max
              TextFormField(
                controller: _maxController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Max Participants"),
              ),
              const SizedBox(height: 30),

              GradientButton(
                onPressed: _submitting ? null : _createGroup,                
                borderRadius: BorderRadius.circular(12),
                height: 50,
                child: _submitting
                  ? const SizedBox(
                      height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(
                      "Create",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
