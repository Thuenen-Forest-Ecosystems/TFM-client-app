import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HeadingLayer {
  /// Build a marker layer showing the user's heading direction as a cone.
  /// Returns null if heading data is not reliable enough to display.
  ///
  /// [position] - current GPS position
  /// [headingDegrees] - heading in degrees (0 = north, 90 = east)
  /// [headingAccuracy] - accuracy of heading in degrees; hidden if > 45°
  /// [source] - 'gps', 'compass', or 'none'
  static MarkerLayer? buildHeadingMarker({
    required LatLng position,
    required double headingDegrees,
    required double headingAccuracy,
    String source = 'gps',
  }) {
    // Hide if no real heading data
    if (source == 'none' || headingAccuracy > 45 || (headingDegrees == 0 && headingAccuracy == 0)) {
      return null;
    }

    return MarkerLayer(
      markers: [
        Marker(
          point: position,
          width: 80,
          height: 80,
          child: _HeadingIndicator(
            headingDegrees: headingDegrees,
            headingAccuracy: headingAccuracy,
            isCompass: source == 'compass',
          ),
        ),
      ],
    );
  }
}

class _HeadingIndicator extends StatelessWidget {
  final double headingDegrees;
  final double headingAccuracy;
  final bool isCompass;

  const _HeadingIndicator({
    required this.headingDegrees,
    required this.headingAccuracy,
    this.isCompass = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: headingDegrees * pi / 180,
      child: CustomPaint(
        size: const Size(80, 80),
        painter: _HeadingConePainter(accuracy: headingAccuracy, isCompass: isCompass),
      ),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  final double accuracy;
  final bool isCompass;

  _HeadingConePainter({required this.accuracy, required this.isCompass});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cone half-angle based on accuracy (min 8°, max 45°)
    final coneHalfAngle = accuracy.clamp(8.0, 45.0) * pi / 180;

    // Draw the heading cone (pointing up = north, rotation is applied by Transform)
    final conePath = ui.Path();
    conePath.moveTo(center.dx, center.dy);

    final startAngle = -pi / 2 - coneHalfAngle;
    final sweepAngle = 2 * coneHalfAngle;

    conePath.arcTo(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false);
    conePath.close();

    // GPS heading = solid blue; compass heading = dashed purple (less certain)
    final Color fillColor = isCompass
        ? const Color(0x33673AB7) // purple with low alpha
        : const Color(0x402196F3); // blue with low alpha
    final Color borderColor = isCompass
        ? const Color(0x99673AB7) // purple
        : const Color(0x992196F3); // blue

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(conePath, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCompass ? 1.0 : 1.5;
    canvas.drawPath(conePath, borderPaint);
  }

  @override
  bool shouldRepaint(_HeadingConePainter oldDelegate) {
    return oldDelegate.accuracy != accuracy || oldDelegate.isCompass != isCompass;
  }
}
