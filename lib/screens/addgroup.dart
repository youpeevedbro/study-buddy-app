import 'package:flutter/material.dart';
import '../components/grad_button.dart';
import 'package:flutter/cupertino.dart';

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
  final TextEditingController _maxController = TextEditingController();

  //Time picker
  void _showCupertinoTimePicker() {
    final now = DateTime.now();

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            // Action bar
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // The wheel picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime: now,
                onDateTimeChanged: (dt) {
                  final tod = TimeOfDay.fromDateTime(dt);
                  final hour = tod.hourOfPeriod.toString().padLeft(2, '0');
                  final minute = dt.minute.toString().padLeft(2, '0');
                  final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
                  setState(() {
                    _startTimeController.text = '$hour:$minute $period';
                  });
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
                onTap: _showCupertinoTimePicker,
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // For now, just print data or later send to backend
                    print("Group Name: ${_groupNameController.text}");
                    print("Location: ${_locationController.text}");
                    print("Date: ${_dateController.text}");
                    print("Start Time: ${_startTimeController.text}");
                    print("Max: ${_maxController.text}");

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Study Group Created!")),
                    );

                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                height: 50,
                child: const Text(
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
