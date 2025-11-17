import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../components/grad_button.dart';
import '../models/group.dart';
import '../services/group_service.dart';

class AddGroupPage extends StatefulWidget {
  const AddGroupPage({super.key});

  @override
  State<AddGroupPage> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends State<AddGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  bool _submitting = false;
  final GroupService _service = const GroupService();

  // Helpers to parse/format "hh:mm AM/PM" to/from TimeOfDay
  TimeOfDay? _parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(value.trim());
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;
    if (period.toUpperCase() == 'PM' && hour != 12) hour += 12;
    if (period.toUpperCase() == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay tod) {
    final hour = tod.hourOfPeriod.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  DateTime _timeOfDayToToday(TimeOfDay tod) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  // Controller-aware Cupertino time picker
  void _showCupertinoTimePickerFor(TextEditingController controller) {
    final now = DateTime.now();
    final initialTod = _parseTime(controller.text) ?? TimeOfDay.now();
    DateTime initial = DateTime(now.year, now.month, now.day, initialTod.hour, initialTod.minute);
    TimeOfDay temp = initialTod;

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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () {
                      setState(() {
                        controller.text = _formatTime(temp);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
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
                  temp = TimeOfDay.fromDateTime(dt); // commit on Done
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 7));

    // Try to keep a previously selected date if it's still in range
    DateTime initial = start;
    if (_dateController.text.isNotEmpty) {
      final parts = _dateController.text.split('/');
      if (parts.length == 3) {
        final parsed = DateTime(
          int.parse(parts[2]),
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (parsed.isBefore(start)) {
          initial = start;
        } else if (parsed.isAfter(end)) {
          initial = end;
        } else {
          initial = parsed;
        }
      }
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: end,
      selectableDayPredicate: (day) {
        final d = DateTime(day.year, day.month, day.day);
        return !(d.isBefore(start) || d.isAfter(end));
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text =
            "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    // Parse date MM/DD/YYYY
    final parts = _dateController.text.split('/');
    if (parts.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid date')),
      );
      return;
    }
    final date = DateTime(
      int.parse(parts[2]),
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    // Enforce date within today..today+7
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 7));
    if (date.isBefore(start) || date.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date must be within the next 7 days')),
      );
      return;
    }

    final startTod = _parseTime(_startTimeController.text);
    final endTod = _parseTime(_endTimeController.text);
    if (startTod == null || endTod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose start and end time')),
      );
      return;
    }

    final group = Group(
      name: _groupNameController.text.trim(),
      date: date,
      startTime: startTod,
      endTime: endTod,
      creatorId: 'user_123',
      building: _buildingController.text.trim(),
      room: _roomNumberController.text.trim(),
    );

    setState(() => _submitting = true);
    try {
      final resp = await _service.createGroup(group);
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Optional: read returned JSON
        // ignore: unused_local_variable
        final _ = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yay! Your new group is created!')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: const Text('Study Buddy'),
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
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a group name' : null,
              ),
              const SizedBox(height: 15),

              // Building
              TextFormField(
                controller: _buildingController,
                decoration: const InputDecoration(labelText: 'Building'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a building' : null,
              ),
              const SizedBox(height: 15),

              // Room Number
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a room number' : null,
              ),
              const SizedBox(height: 15),

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

              // Start Time
              TextFormField(
                controller: _startTimeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Start Time',
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
                  labelText: 'End Time',
                  suffixIcon: Icon(Icons.access_time),
                ),
                onTap: () => _showCupertinoTimePickerFor(_endTimeController),
              ),
              const SizedBox(height: 30),

              GradientButton(
                onPressed: _submitting ? null : _createGroup,
                borderRadius: BorderRadius.circular(12),
                height: 50,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create',
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