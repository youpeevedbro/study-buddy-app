import 'package:study_buddy/components/square_button.dart';
import 'package:flutter/material.dart';
import 'profile.dart'; 

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
              SizedBox(
                height: 60,
                width: double.infinity,
                child: CursiveDivider(
                  color: const Color(0xFFfcbf49),
                  strokeWidth: 10,
                ),
              ),
              SizedBox(height: 30),
              // top row
              Row(
                children: [
                  SquareButton(
                    text: "Account\nSettings",
                    onPressed: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserProfilePage()),
                      );
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



// ---------------------Cursive / wavy divider painter--------------------------
class CursiveDivider extends StatelessWidget {
  final Color color;
  final double strokeWidth;

  const CursiveDivider({
    super.key,
    this.color = Colors.black,
    this.strokeWidth = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CursiveDividerPainter(color: color, strokeWidth: strokeWidth),
      size: Size.infinite,
    );
  }
}

class _CursiveDividerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CursiveDividerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Draw a flowing bezier curve across the width
    path.moveTo(0, h * 0.6);
    path.cubicTo(w * 0.15, h * 0.1, w * 0.35, h * 0.9, w * 0.5, h * 0.5);
    path.cubicTo(w * 0.65, h * 0.1, w * 0.85, h * 0.9, w, h * 0.6);

    // Optional secondary thinner stroke for calligraphic feel
    final shadowPaint = Paint()
      ..color = color.withAlpha(64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

