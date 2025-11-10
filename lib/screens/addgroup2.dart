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
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  bool _submitting = false;
  final GroupService _service = const GroupService();

  // Helpers to parse/format "hh:mm AM/PM"
  DateTime? _parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(value.trim());
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;
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

    final start = _parseTime(_startTimeController.text);
    final end = _parseTime(_endTimeController.text);
    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose start and end time')),
      );
      return;
    }

    final group = Group(
      name: _groupNameController.text.trim(),
      date: date,
      startTime: start,
      endTime: end,
      maxMembers: int.tryParse(_maxController.text.trim()) ?? 0,
      creatorId: 'user_123',
      room: Room(
        building: _buildingController.text.trim(),
        number: _roomNumberController.text.trim(),
        floor: _floorController.text.trim().isEmpty
            ? null
            : _floorController.text.trim(),
      ),
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

              // Floor (optional)
              TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(
                  labelText: 'Floor (optional)',
                ),
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
              const SizedBox(height: 15),

              // Max
              TextFormField(
                controller: _maxController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Max Participants'),
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
