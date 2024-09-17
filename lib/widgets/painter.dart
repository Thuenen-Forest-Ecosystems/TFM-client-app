import 'package:flutter/material.dart';

class ImageEditor extends CustomPainter {
  ImageEditor();

  @override
  void paint(Canvas canvas, Size size) async {
    const double width = 50;

    final path = Path();
    path.moveTo(0, 0);

    path.lineTo(width, 0);

    path.quadraticBezierTo(
      0,
      0,
      0,
      width,
    );

    path.lineTo(0, 0); // Top left corner
    path.close();

    path.close();

    final paint = Paint()..color = const Color(0xFFC3E399);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
