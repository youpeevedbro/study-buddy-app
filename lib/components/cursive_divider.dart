import 'package:flutter/material.dart';


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
