import 'package:study_buddy/components/square_button.dart';
import 'package:flutter/material.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        margin: EdgeInsets.only(top: 100.0),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              Text(
                "Hello, Student",
                style: TextStyle(fontFamily: "BrittanySignature", fontSize: 65),
              ),
              SizedBox(height: 30),
              Divider(
                thickness: 10,
                indent: 0,
                endIndent: 0,
                color: Color(0xFFfcbf49),
              ),
              SizedBox(height: 30),
              // top row
              Row(
                children: [
                  SquareButton(
                    text: "Account\nSettings",
                    onPressed: () {
                      print("OK pressed!");
                    },
                    backgroundColor: Color(0xFFf79f79),
                  ),
                  SizedBox(width: 30),
                  SquareButton(
                    text: "Find Study\nGroup",
                    onPressed: () {
                      print("OK pressed!");
                    },
                    backgroundColor: Color(0xFFf7d08a),
                  ),
                ],
              ),
              SizedBox(height: 30),
              // bottom row
              Row(
                children: [
                  SquareButton(
                    text: "Find\nRoom",
                    onPressed: () {
                      print("OK pressed!");
                    },
                    backgroundColor: Color(0xFFbfd7b5),
                  ),
                  SizedBox(width: 30),
                  SquareButton(
                    text: "My\nActivities",
                    onPressed: () {
                      print("OK pressed!");
                    },
                    backgroundColor: Color(0xFFffd6af),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
