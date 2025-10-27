import 'package:flutter/material.dart';
import '../services/timer_service.dart';

class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({super.key});

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage> {
  bool _userCheckedIn = true;

  void _checkOutRoom() {
    setState(() {
      _userCheckedIn = false;
      //Remove User from Room
    });
    TimerService.instance.stop();
  }

  Future<void> _showSetTimerDialog() async {
    final controller = TextEditingController();
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set timer (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter minutes, e.g. 60',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val == null || val <= 0) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number of minutes.')),
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (minutes != null && minutes > 0) {
      TimerService.instance.start(Duration(minutes: minutes));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timer started for $minutes minute(s).')),
      );
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
          onPressed: () => Navigator.pop(context), // back to Dashboard
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
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "My Activities",
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.w900,
                )
              ),
              const Divider(
                thickness: 1.5,
                color: Colors.black,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/mystudygroups'); // <-- go to My Study Groups
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  fixedSize: const Size.fromHeight(60),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800, 
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(12)
                  )
                ),
                child: const Text('My Study Groups'),
              ),
              SizedBox(height: 100),
              Text(
                "My Check-in Room",
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                )
              ),
              const Divider(
                thickness: 1.2,
                color: Colors.black,
                endIndent: 60,
              ),
              SizedBox(height: 20),
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _userCheckedIn? Row( children: [
                  SizedBox(width: 15),
                  Text(
                    'Room Number',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    )
                  ), 
                  const Spacer(),
                  //Check-out
                  ElevatedButton(
                    onPressed: _checkOutRoom, 
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontFamily: "SuperLobster"
                      ),
                    ), 
                    child: const Text("Check-out"),
                  ),
                  SizedBox(width: 10)
                  ]
                )
                : Center(
                    child: Text(
                      "You are currently not checked into a room",
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'SuperLobster'
                      )
                    )
                  )
              ),
              if (_userCheckedIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showSetTimerDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontFamily: "SuperLobster",
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.timer),
                        SizedBox(width: 8),
                        Text("Set timer"),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          )
        )
      )
    );
  }
}