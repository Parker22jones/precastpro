import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import 'cad_palette.dart';
import 'label_layout.dart';

/// Top-down CAD plan: the barrel with every penetration placed at its exact
/// clockwise angle off a 0 degree North heading, with a diameter dimension
/// string and hole callouts.
class PlanPainter extends CustomPainter {
  PlanPainter({
    required this.insideDiameterIn,
    required this.wallThicknessIn,
    required this.pipes,
    required this.conflictedPipes,
    this.palette = CadPalette.light,
    this.title = 'PLAN VIEW',
  });

  final double insideDiameterIn;
  final double wallThicknessIn;
  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;
  final CadPalette palette;
  final String title;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
    final labels = LabelPlacer(size);

    final center = Offset(size.width / 2, size.height / 2 + 8);
    final outsideRadiusIn = insideDiameterIn / 2 + wallThicknessIn;
    final available = math.min(size.width, size.height) / 2 - 86;
    final scale = math.max(available, 20.0) / (outsideRadiusIn + 14);

    double r(double inches) => inches * scale;
    Offset pt(double angleDeg, double radiusIn) => polar(center, r(radiusIn), angleDeg);

    // Border + title block.
    final border = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawRect(border, _stroke(palette.ink, 1.2));
    canvas.drawLine(const Offset(3, 22), Offset(size.width - 3, 22), _stroke(palette.thinInk, 0.8));
    labels.draw(canvas, title, const Offset(9, 6), 11.5, bold: true, color: palette.ink);
    labels.draw(
      canvas,
      '${insideDiameterIn.toStringAsFixed(0)}" I.D. x '
      '${wallThicknessIn.toStringAsFixed(0)}" WALL',
      Offset(size.width - 9, 6),
      9,
      align: LabelAnchor.right,
      color: palette.thinInk,
    );

    // Wall annulus.
    canvas.drawCircle(center, r(outsideRadiusIn), Paint()..color = palette.concrete);
    canvas.drawCircle(center, r(insideDiameterIn / 2), Paint()..color = palette.paper);
    canvas.drawCircle(center, r(outsideRadiusIn), _stroke(palette.ink, 1.6));
    canvas.drawCircle(center, r(insideDiameterIn / 2), _stroke(palette.ink, 1.6));

    // Centre cross-hairs (CAD centre mark).
    final crossPaint = _stroke(palette.thinInk, 0.8);
    canvas.drawLine(
      center - Offset(r(outsideRadiusIn) + 8, 0),
      center + Offset(r(outsideRadiusIn) + 8, 0),
      crossPaint,
    );
    canvas.drawLine(
      center - Offset(0, r(outsideRadiusIn) + 8),
      center + Offset(0, r(outsideRadiusIn) + 8),
      crossPaint,
    );

    // Inside-diameter dimension string across the barrel.
    drawDimensionLine(
      canvas,
      center - Offset(r(insideDiameterIn / 2), 0),
      center + Offset(r(insideDiameterIn / 2), 0),
      palette.dimension,
    );
    labels.draw(
      canvas,
      '\u00D8 ${insideDiameterIn.toStringAsFixed(0)}" I.D.',
      Offset(center.dx, center.dy + 4),
      9,
      align: LabelAnchor.center,
      color: palette.dimension,
      avoidOverlap: false,
    );

    // Clock ticks every 30 degrees.
    for (var a = 0; a < 360; a += 30) {
      final p1 = pt(a.toDouble(), outsideRadiusIn);
      final p2 = pt(a.toDouble(), outsideRadiusIn + 5);
      canvas.drawLine(p1, p2, _stroke(palette.thinInk, 1));
      final labelPt = pt(a.toDouble(), outsideRadiusIn + 12);
      labels.draw(
        canvas,
        '$a\u00B0',
        labelPt - const Offset(0, 5),
        7.5,
        align: LabelAnchor.center,
        color: palette.thinInk,
        avoidOverlap: false,
      );
    }

    // North arrow at the 0 degree heading.
    final nTip = pt(0, outsideRadiusIn + 28);
    final nTail = pt(0, outsideRadiusIn + 8);
    drawLeader(canvas, nTail, nTip, palette.ink);
    labels.reserve(LabelPlacer.corridor(nTail, nTip, pad: 5));
    labels.draw(
      canvas,
      'N  0\u00B0',
      nTip - const Offset(0, 18),
      10.5,
      align: LabelAnchor.center,
      bold: true,
      color: palette.ink,
    );

    // Pipe penetrations.
    for (final pipe in pipes) {
      final conflicted = conflictedPipes.contains(pipe.name);
      final color = conflicted ? palette.conflict : palette.pipe;
      final angle = pipe.normalizedAngleDeg;
      final halfAngleDeg = _halfAngleDeg(pipe.holeSizeIn / 2, outsideRadiusIn);

      // Cored opening through the wall.
      final opening = Path()
        ..moveTo(
          pt(angle - halfAngleDeg, insideDiameterIn / 2).dx,
          pt(angle - halfAngleDeg, insideDiameterIn / 2).dy,
        )
        ..lineTo(
          pt(angle - halfAngleDeg, outsideRadiusIn + 18).dx,
          pt(angle - halfAngleDeg, outsideRadiusIn + 18).dy,
        )
        ..lineTo(
          pt(angle + halfAngleDeg, outsideRadiusIn + 18).dx,
          pt(angle + halfAngleDeg, outsideRadiusIn + 18).dy,
        )
        ..lineTo(
          pt(angle + halfAngleDeg, insideDiameterIn / 2).dx,
          pt(angle + halfAngleDeg, insideDiameterIn / 2).dy,
        )
        ..close();
      canvas.drawPath(opening, Paint()..color = color.withValues(alpha: conflicted ? 0.30 : 0.14));
      canvas.drawPath(opening, _stroke(color, 1.6));

      // Radial centreline out from the structure centre.
      canvas.drawLine(center, pt(angle, outsideRadiusIn + 18), _stroke(color, 1.0));
      labels.reserve(
        LabelPlacer.corridor(pt(angle, outsideRadiusIn), pt(angle, outsideRadiusIn + 18), pad: 2),
      );

      // Angular callout: arc from North to the pipe heading.
      _angleArc(canvas, center, r(outsideRadiusIn) * 0.55, angle, palette.dimension);

      final holeCoords = pipe.holeCoordinates(outsideRadiusIn);
      final labelPt = pt(angle, outsideRadiusIn + 32);
      final dx = labelPt.dx - center.dx;
      final align = dx.abs() < r(outsideRadiusIn) * 0.35
          ? LabelAnchor.center
          : dx < 0
          ? LabelAnchor.right
          : LabelAnchor.left;
      labels.draw(
        canvas,
        '${pipe.name}  ${pipe.material.label}\n'
        '${angle.toStringAsFixed(0)}\u00B0 CW FROM N (${pipe.clockPosition})\n'
        'HOLE \u00D8${pipe.holeSizeIn.toStringAsFixed(1)}"  '
        'E${holeCoords.eastIn.toStringAsFixed(1)} N${holeCoords.northIn.toStringAsFixed(1)}',
        labelPt - const Offset(0, 12),
        8.5,
        align: align,
        color: color,
      );
    }

    if (conflictedPipes.isNotEmpty) {
      labels.draw(
        canvas,
        '!! PENETRATION CONFLICT',
        Offset(10, size.height - 20),
        11,
        bold: true,
        color: palette.conflict,
      );
    }
  }

  /// Small arc with an arrowhead showing the clockwise angle off North.
  void _angleArc(Canvas canvas, Offset center, double radius, double angleDeg, Color color) {
    if (angleDeg < 4) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = angleDeg * math.pi / 180.0;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, _stroke(color, 0.9));
    final end = polar(center, radius, angleDeg);
    final tangent = Offset(
      math.cos((angleDeg) * math.pi / 180.0),
      math.sin(angleDeg * math.pi / 180.0),
    );
    drawLeader(canvas, end - tangent * 6, end, color);
  }

  double _halfAngleDeg(double pipeRadiusIn, double structureRadiusIn) {
    final ratio = (pipeRadiusIn / structureRadiusIn).clamp(-0.999, 0.999);
    return math.asin(ratio) * 180 / math.pi;
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(covariant PlanPainter oldDelegate) => true;
}
