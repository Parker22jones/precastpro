import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pipe_penetration.dart';

/// Top-down view: the structure barrel with every penetration placed at its
/// exact clockwise angle.
class PlanPainter extends CustomPainter {
  PlanPainter({
    required this.insideDiameterIn,
    required this.wallThicknessIn,
    required this.pipes,
    required this.conflictedPipes,
    this.background = Colors.white,
  });

  final double insideDiameterIn;
  final double wallThicknessIn;
  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;
  final Color background;

  static const _concrete = Color(0xFFD7D3CC);
  static const _outline = Color(0xFF37474F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final center = Offset(size.width / 2, size.height / 2 + 8);
    final outsideRadiusIn = insideDiameterIn / 2 + wallThicknessIn;
    final available = math.min(size.width, size.height) / 2 - 54;
    final scale = math.max(available, 20.0) / (outsideRadiusIn + 14);

    double r(double inches) => inches * scale;
    Offset pt(double angleDeg, double radiusIn) {
      final rad = (angleDeg - 90) * math.pi / 180.0; // 0 deg = up, clockwise
      return center + Offset(math.cos(rad), math.sin(rad)) * r(radiusIn);
    }

    _label(canvas, 'PLAN VIEW', const Offset(10, 6), 12, bold: true, color: const Color(0xFF263238));
    _label(canvas, '${insideDiameterIn.toStringAsFixed(0)}" I.D. x ${wallThicknessIn.toStringAsFixed(0)}" WALL',
        Offset(size.width - 10, 6), 9,
        alignRight: true, color: const Color(0xFF607D8B));

    // Wall annulus.
    canvas.drawCircle(center, r(outsideRadiusIn), Paint()..color = _concrete);
    canvas.drawCircle(center, r(insideDiameterIn / 2), Paint()..color = background);
    canvas.drawCircle(center, r(outsideRadiusIn), _stroke(_outline, 1.6));
    canvas.drawCircle(center, r(insideDiameterIn / 2), _stroke(_outline, 1.6));

    // Clock ticks every 30 degrees.
    for (var a = 0; a < 360; a += 30) {
      final p1 = pt(a.toDouble(), outsideRadiusIn);
      final p2 = pt(a.toDouble(), outsideRadiusIn + 5);
      canvas.drawLine(p1, p2, _stroke(const Color(0xFF90A4AE), 1));
      final labelPt = pt(a.toDouble(), outsideRadiusIn + 12);
      _label(canvas, '$a°', labelPt - const Offset(9, 5), 7.5, color: const Color(0xFF78909C));
    }

    // North arrow.
    final nTip = pt(0, outsideRadiusIn + 26);
    final nTail = pt(0, outsideRadiusIn + 8);
    canvas.drawLine(nTail, nTip, _stroke(const Color(0xFF263238), 1.6));
    final head = Path()
      ..moveTo(nTip.dx, nTip.dy)
      ..lineTo(nTip.dx - 4, nTip.dy + 8)
      ..lineTo(nTip.dx + 4, nTip.dy + 8)
      ..close();
    canvas.drawPath(head, Paint()..color = const Color(0xFF263238));
    _label(canvas, 'N', nTip - const Offset(4, 18), 11, bold: true, color: const Color(0xFF263238));

    // Pipe penetrations.
    for (final pipe in pipes) {
      final conflicted = conflictedPipes.contains(pipe.name);
      final color = conflicted ? const Color(0xFFD50000) : const Color(0xFF00695C);
      final angle = pipe.normalizedAngleDeg;
      final halfAngleDeg = _halfAngleDeg(pipe.outsideDiameterIn / 2, outsideRadiusIn);

      // Opening through the wall.
      final opening = Path()
        ..moveTo(pt(angle - halfAngleDeg, insideDiameterIn / 2).dx,
            pt(angle - halfAngleDeg, insideDiameterIn / 2).dy)
        ..lineTo(pt(angle - halfAngleDeg, outsideRadiusIn + 18).dx,
            pt(angle - halfAngleDeg, outsideRadiusIn + 18).dy)
        ..lineTo(pt(angle + halfAngleDeg, outsideRadiusIn + 18).dx,
            pt(angle + halfAngleDeg, outsideRadiusIn + 18).dy)
        ..lineTo(pt(angle + halfAngleDeg, insideDiameterIn / 2).dx,
            pt(angle + halfAngleDeg, insideDiameterIn / 2).dy)
        ..close();
      canvas.drawPath(opening, Paint()..color = color.withValues(alpha: conflicted ? 0.30 : 0.16));
      canvas.drawPath(opening, _stroke(color, 1.6));

      // Centerline.
      canvas.drawLine(center, pt(angle, outsideRadiusIn + 18), _stroke(color, 1.0));

      final labelPt = pt(angle, outsideRadiusIn + 30);
      _label(
        canvas,
        '${pipe.name}\n${pipe.outsideDiameterIn.toStringAsFixed(1)}" @ '
        '${angle.toStringAsFixed(0)}° (${pipe.clockPosition})',
        labelPt - Offset(angle > 180 ? 2 : -2, 10),
        8.5,
        alignRight: angle > 180,
        color: color,
      );
    }

    if (conflictedPipes.isNotEmpty) {
      _label(canvas, '⚠ PENETRATION CONFLICT', Offset(10, size.height - 20), 11,
          bold: true, color: const Color(0xFFD50000));
    }
  }

  double _halfAngleDeg(double pipeRadiusIn, double structureRadiusIn) {
    final ratio = (pipeRadiusIn / structureRadiusIn).clamp(-0.999, 0.999);
    return math.asin(ratio) * 180 / math.pi;
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double fontSize, {
    bool alignRight = false,
    bool bold = false,
    Color color = Colors.black,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
    )..layout();
    painter.paint(canvas, alignRight ? Offset(at.dx - painter.width, at.dy) : at);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(covariant PlanPainter oldDelegate) => true;
}
