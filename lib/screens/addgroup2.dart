import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:study_buddy/screens/findroom_forgroup.dart';
import 'dart:convert';

import '../components/grad_button.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import 'package:intl/intl.dart';

class AddGroupPage extends StatefulWidget {
  const AddGroupPage({super.key});

  @override
  State<AddGroupPage> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends State<AddGroupPage> {
  final _dateFieldKey = GlobalKey<FormFieldState>();
  final _formKeyForGroupCreation = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();  
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  bool _submitting = false;
  bool _canEdit = true;
  bool _canEditTime = false;
  final GroupService _service = const GroupService();

  SelectedGroupFields? _groupFields;

  String _formatDate(DateTime d) {
    DateFormat formattedDate = DateFormat('yyyy-MM-dd');
    String date = formattedDate.format(d);
    return date;
  }

  TimeOfDay? _parseHHMM(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }

  Future<JoinedGroup?> _checkOverlappingGroups(DateTime newStart, DateTime newEnd) async {
    try {
      List<JoinedGroup> groups = await _service.listMyStudyGroups();
      
      for (JoinedGroup group in groups) {
        DateTime groupDate = DateTime.parse(group.date);
        final start = _parseHHMM(group.startTime);
        final end = _parseHHMM(group.endTime);
        if (start == null || end == null) {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to check for overlapping groups')),
          );
          return null;
        } 

        DateTime groupStart = DateTime(groupDate.year, groupDate.month, groupDate.day, start.hour, start.minute);
        DateTime groupEnd = DateTime(groupDate.year, groupDate.month, groupDate.day, end.hour, end.minute);
        
        if (!(groupStart.isAfter(newEnd) || newStart.isAfter(groupEnd))) {
          return group;
        }
      }
      
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } 
    return null;
  }

  

  void _reload() {
    setState(() {
      _formKeyForGroupCreation.currentState!.reset();
      _dateController.text = _formatDate(_groupFields!.date!);
      _buildingController.text = _groupFields!.building!;
      _roomController.text = _groupFields!.roomNumber!;
      _startTimeController.text = _formatTime(_groupFields!.startTime!);
      _endTimeController.text = _formatTime(_groupFields!.endTime!);
      _canEdit = false;
      _canEditTime = true;
    });
  }

  void _navigateToFindRoomForGroup() async {
    if (!_dateFieldKey.currentState!.validate()) return;
    final filters = SelectedGroupFields(date: DateTime.parse(_dateController.text));
    
    final newTimeSlot = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FindRoomForGroupPage(initialFilters: filters)),
    );
    
    if (newTimeSlot != null) {
      setState(() => _groupFields = newTimeSlot);
      _reload();
    }
  }

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
    if (!_canEditTime) return;
    final date = _groupFields!.date!;         
    final start = _groupFields!.startTime!;  //contains start and end times from the availabilityslot chosen
    final end = _groupFields!.endTime!;
    DateTime minTime = DateTime(date.year, date.month, date.day, start.hour, start.minute); 
    DateTime maxTime = DateTime(date.year, date.month, date.day, end.hour, end.minute);

    final initialTod = _parseTime(controller.text) ?? TimeOfDay.now();
    DateTime initial = DateTime(date.year, date.month, date.day, initialTod.hour, initialTod.minute);
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
                minimumDate: minTime,   //cannot set time outside of availslot range
                maximumDate: maxTime,
                minuteInterval: 5,
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
    if (!_canEdit) return;

    // Define allowed window: today -> 7 days from today (inclusive)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekOut = today.add(const Duration(days: 7));

    // Try to use the currently selected date, but clamp it to [today, weekOut]
    final text = _dateController.text;
    DateTime initialDate;
    final parsed = text.isNotEmpty ? DateTime.tryParse(text) : null;

    if (parsed != null) {
      if (parsed.isBefore(today)) {
        initialDate = today;
      } else if (parsed.isAfter(weekOut)) {
        initialDate = weekOut;
      } else {
        initialDate = parsed;
      }
    } else {
      initialDate = today;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: weekOut,
    );

    if (picked != null) {
      setState(() {
        _dateController.text = _formatDate(picked); // yyyy-MM-dd
      });
    }
  }


  
  Future<void> _createGroup() async {
    if (!_formKeyForGroupCreation.currentState!.validate()) return;

    DateTime date = DateTime.parse(_dateController.text);

    
    final startTime = _parseTime(_startTimeController.text);
    final endTime = _parseTime(_endTimeController.text);
    if (startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Times invalid.')),
      );
      return;
    }
    if (startTime.isAfter(endTime) || startTime.isAtSameTimeAs(endTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    DateTime groupStart = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
    DateTime groupEnd = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
    final result = await _checkOverlappingGroups(groupStart, groupEnd);
    if (result != null) {
      _showOverlappedGroupDialog(context, result);
      /*
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot create group as the following study group overlaps in time: ${result.name}')),
      );*/
      return;
    }

    final group = SelectedGroupFields(
      name: _groupNameController.text.trim(),
      date: date,
      building: _buildingController.text.trim(),
      roomNumber: _roomController.text.trim(),
      startTime: startTime,
      endTime: endTime,
      availabilitySlotDoc: _groupFields!.availabilitySlotDoc
    );

setState(() => _submitting = true);

try {
  await _service.createStudyGroup(group);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        'Successfully created Study Group',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor:const Color(0xFF81C784), 
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      duration: const Duration(seconds: 2),
    ),
  );

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Error: $e',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFE53935), 
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
} finally {
  if (mounted) setState(() => _submitting = false);
}

  }


String formatDate(String yyyymmdd) {
  try {
    final parsed = DateTime.parse(yyyymmdd);
    return DateFormat("MMM d, yyyy").format(parsed);
  } catch (_) {
    return yyyymmdd;
  }
}

String formatTo12Hour(String time24h) {
  try {
    final parsed = DateTime.parse("2020-01-01 $time24h:00");
    return DateFormat("h:mm a").format(parsed);
  } catch (_) {
    return time24h;
  }
}

Future<void> _showOverlappedGroupDialog(
    BuildContext context,
    JoinedGroup group,
  ) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFFF4E9D8), // same beige tone
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),

        // ----- ERROR HEADER (icon + red text) -----
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "Error",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),

        // ----- MESSAGE -----
        content: Text(
          "Cannot create study group.\n"
          "Time overlap with the following joined group: "
          "${group.name}\n\n"
          "Date: ${formatDate(group.date)}\n"
          "Time: ${formatTo12Hour(group.startTime)} - ${formatTo12Hour(group.endTime)}",
          style: const TextStyle(fontSize: 14),
        ),

        // ----- OK BUTTON -----
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "OK",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.brown, // matches your other popups
              ),
            ),
          ),
        ],
      );
    },
  );
}


  @override
  void dispose() {
  _groupNameController.dispose();
  _buildingController.dispose();
  _roomController.dispose();
  _dateController.dispose();
  _startTimeController.dispose(); 
  _endTimeController.dispose();
  super.dispose();
  }
  

   @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      // ⬅️ Gradient now wraps the entire page (including AppBar)
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFCF8), // very light cream (almost white)
            Color(0xFFFFF0C9), // soft light yellow
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors
            .transparent, // let the gradient show through the Scaffold
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
          backgroundColor: Colors
              .transparent, // ⬅️ transparent so gradient shows behind AppBar
          foregroundColor: Colors.black,
          titleTextStyle: const TextStyle(
            fontFamily: 'BrittanySignature',
            fontSize: 40,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKeyForGroupCreation,
              child: ListView(
                children: [
                  const SizedBox(height: 10),

                  // Group Name
                  TextFormField(
                  maxLength: 60,
                    controller: _groupNameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'You must enter a group name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Date (Calendar)
                  TextFormField(
                    key: _dateFieldKey,
                    controller: _dateController,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'You must enter a date to see time slots';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Date (MM/DD/YYYY)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () {
                      if (_canEdit == true) {
                        _selectDate(context);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  GradientButton(
                    onPressed: () => _navigateToFindRoomForGroup(),
                    borderRadius: BorderRadius.circular(12),
                    height: 40,
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
                            'Find time slots',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                  ),
                  const SizedBox(height: 30),

                  // Building
                  TextFormField(
                    controller: _buildingController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Find Time Slots to set a building';
                      }
                      return null;
                    },
                    readOnly: true,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      labelText: 'Building',
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Room Number
                  TextFormField(
                    controller: _roomController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Find Time Slots to set a room';
                      }
                      return null;
                    },
                    readOnly: true,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(labelText: 'Room Number'),
                  ),
                  const SizedBox(height: 15),

                  // Start Time
                  TextFormField(
                    controller: _startTimeController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Find Time Slots to set a start time';
                      }
                      return null;
                    },
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Start Time',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    onTap: () =>
                        _showCupertinoTimePickerFor(_startTimeController),
                  ),
                  const SizedBox(height: 15),

                  // End Time
                  TextFormField(
                    controller: _endTimeController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Find Time Slots to set an end time';
                      }
                      return null;
                    },
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'End Time',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    onTap: () =>
                        _showCupertinoTimePickerFor(_endTimeController),
                  ),
                  const SizedBox(height: 30),

                  GradientButton(
                    onPressed: () => _createGroup(),
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
                            'Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}