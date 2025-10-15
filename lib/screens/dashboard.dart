import 'package:flutter/material.dart';
import 'package:study_buddy/components/square_button.dart';
import '../services/auth_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        margin: const EdgeInsets.only(top: 100.0),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const Text(
                "Hello, Student",
                style: TextStyle(fontFamily: "BrittanySignature", fontSize: 65),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                height: 60,
                width: double.infinity,
                child: CursiveDivider(
                  color: Color(0xFFfcbf49),
                  strokeWidth: 10,
                ),
              ),
              const SizedBox(height: 30),

              // top row
              Row(
                children: [
                  SquareButton(
                    text: "Account\nSettings",
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile'); // <-- go to profile
                    },
                    backgroundColor: const Color(0xFFf79f79),
                  ),
                  const SizedBox(width: 30),
                  SquareButton(
                    text: "Find Study\nGroup",
                    onPressed: () {},
                    backgroundColor: const Color(0xFFf7d08a),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // bottom row
              Row(
                children: [
                  SquareButton(
                    text: "Find\nRoom",
                    onPressed: () {
                      Navigator.pushNamed(context, '/rooms'); 
                    },
                    backgroundColor: const Color(0xFFbfd7b5),
                  ),
                  const SizedBox(width: 30),
                  SquareButton(
                    text: "My\nActivities",
                    onPressed: () {
                      Navigator.pushNamed(context, "/activities");
                    },
                    backgroundColor: const Color(0xFFffd6af),
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

    path.moveTo(0, h * 0.6);
    path.cubicTo(w * 0.15, h * 0.1, w * 0.35, h * 0.9, w * 0.5, h * 0.5);
    path.cubicTo(w * 0.65, h * 0.1, w * 0.85, h * 0.9, w, h * 0.6);

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
