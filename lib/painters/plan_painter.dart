import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pipe_penetration.dart';
import 'cad_palette.dart';
import 'label_layout.dart';

/// Top-down CAD plan drawn like the shop submittals: concentric barrel
/// circles, a dashed compass crosshair with a fixed 0 degree North arrow,
/// diameter dimension strings and a directional flow line per penetration
/// labelled with its exact clock angle.
class PlanPainter extends CustomPainter {
  PlanPainter({
    required this.insideDiameterIn,
    required this.wallThicknessIn,
    required this.pipes,
    required this.conflictedPipes,
    this.topOpeningDiameterIn = 24,
    this.palette = CadPalette.light,
    this.title = 'PLAN VIEW',
  });

  final double insideDiameterIn;
  final double wallThicknessIn;
  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;

  /// Access opening of the top set over the barrel, in inches.
  final double topOpeningDiameterIn;
  final CadPalette palette;
  final String title;

  /// Pipe stub length outside the wall, in inches.
  static const double _stubIn = 14;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
    final labels = LabelPlacer(size);

    _drawSheet(canvas, size, labels);

    final center = Offset(size.width / 2, size.height / 2 + 10);
    final insideR = math.max(insideDiameterIn / 2, 1.0);
    final outsideR = insideR + wallThicknessIn;
    final margin = math.min(72.0, math.min(size.width, size.height) * 0.14);
    final available = math.max(math.min(size.width, size.height) / 2 - margin, 18.0);
    final scale = available / (outsideR + _stubIn);

    double r(double inches) => inches * scale;
    Offset pt(double angleDeg, double radiusIn) => polar(center, r(radiusIn), angleDeg);
    Offset atPx(double angleDeg, double radiusPx) => polar(center, radiusPx, angleDeg);
    final outsidePx = r(outsideR);

    _drawBarrel(canvas, center, r, insideR, outsideR);
    _drawCompass(canvas, labels, center, outsidePx);
    _drawDiameterStrings(canvas, labels, center, r, insideR);
    _drawNorthArrow(canvas, labels, atPx, outsidePx);

    // Pipe callouts claim their space before the decorative clock labels.
    for (final pipe in pipes) {
      _drawPipe(canvas, labels, size, center, r, pt, pipe, insideR, outsideR);
    }
    _drawClockTicks(canvas, labels, atPx, outsidePx);

    if (conflictedPipes.isNotEmpty) {
      labels.draw(
        canvas,
        '!! PENETRATION CONFLICT',
        Offset(size.width - 9, size.height - 19),
        10.5,
        align: LabelAnchor.right,
        bold: true,
        color: palette.conflict,
        avoidOverlap: false,
      );
    }
  }

  void _drawSheet(Canvas canvas, Size size, LabelPlacer labels) {
    final border = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawRect(border, cadStroke(palette.ink, 1.0));
    canvas.drawLine(
      const Offset(3, 22),
      Offset(size.width - 3, 22),
      cadStroke(palette.ink, CadWeight.thin),
    );
    labels.draw(canvas, title.toUpperCase(), const Offset(9, 6), 11, bold: true, color: palette.ink);
    labels.draw(
      canvas,
      '${inchesText(insideDiameterIn)}" I.D. x ${inchesText(wallThicknessIn)}" WALL',
      Offset(size.width - 9, 7),
      8.5,
      align: LabelAnchor.right,
      color: palette.callout,
    );
    labels.draw(
      canvas,
      'ANGLES CLOCKWISE FROM FIXED 0\u00B0 NORTH',
      Offset(9, size.height - 18),
      8,
      color: palette.callout,
      avoidOverlap: false,
    );
    // Title bar and footer note are off limits to every other annotation.
    labels.topGuard = 26;
    labels.bottomGuard = 22;
  }

  /// Dashed compass crosshair through the structure centre.
  void _drawCompass(Canvas canvas, LabelPlacer labels, Offset center, double outsideR) {
    final paint = cadStroke(palette.thinInk, CadWeight.thin);
    final reach = outsideR + 30;
    drawDashedLine(canvas, center - Offset(reach, 0), center + Offset(reach, 0), paint, dash: 7, gap: 4);
    drawDashedLine(canvas, center - Offset(0, reach), center + Offset(0, reach), paint, dash: 7, gap: 4);
    labels.reserve(Rect.fromCircle(center: center, radius: 6));
  }

  void _drawBarrel(Canvas canvas, Offset center, double Function(double) r, double insideR, double outsideR) {
    canvas.drawCircle(center, r(outsideR), Paint()..color = palette.concrete);
    canvas.drawCircle(center, r(outsideR), cadStroke(palette.ink, CadWeight.outline));
    canvas.drawCircle(center, r(insideR), cadStroke(palette.ink, CadWeight.outline));
    // Access opening of the top, shown lighter as it sits above the barrel.
    final openingR = math.min(topOpeningDiameterIn / 2, insideR);
    canvas.drawCircle(center, r(openingR), cadStroke(palette.thinInk, CadWeight.hidden));
  }

  /// Diagonal diameter dimension strings, as drawn on the submittals.
  void _drawDiameterStrings(
    Canvas canvas,
    LabelPlacer labels,
    Offset center,
    double Function(double) r,
    double insideR,
  ) {
    void diameter(double angleDeg, double radiusIn, String text) {
      final a = polar(center, r(radiusIn), angleDeg);
      final b = polar(center, r(radiusIn), angleDeg + 180);
      drawDimensionLine(canvas, a, b, palette.dimension, head: 5);
      labels.reserve(LabelPlacer.corridor(a, b, pad: 3));
      // Parked along the string, not on the centre, so the callouts stay clear.
      final at = polar(center, r(radiusIn) * 0.55, angleDeg);
      labels.draw(
        canvas,
        text,
        at + const Offset(0, -16),
        9.5,
        align: LabelAnchor.center,
        color: palette.dimension,
      );
    }

    diameter(48, insideR, '${inchesText(insideDiameterIn)}\u00F8');
    final openingR = math.min(topOpeningDiameterIn / 2, insideR);
    if (openingR < insideR - 1) {
      diameter(132, openingR, '${inchesText(openingR * 2)}\u00F8');
    }
  }

  void _drawClockTicks(
    Canvas canvas,
    LabelPlacer labels,
    Offset Function(double, double) atPx,
    double outsidePx,
  ) {
    for (var a = 0; a < 360; a += 30) {
      canvas.drawLine(
        atPx(a.toDouble(), outsidePx),
        atPx(a.toDouble(), outsidePx + 6),
        cadStroke(palette.thinInk, CadWeight.thin),
      );
      final crowded = pipes.any((p) {
        final delta = (p.normalizedAngleDeg - a).abs() % 360;
        return math.min(delta, 360 - delta) < 20;
      });
      if (a % 90 == 0 && a != 0 && !crowded) {
        labels.draw(
          canvas,
          '$a\u00B0',
          atPx(a.toDouble(), outsidePx + 17) - const Offset(0, 5),
          7.5,
          align: LabelAnchor.center,
          color: palette.thinInk,
          avoidOverlap: false,
        );
      }
    }
  }

  /// Prominent fixed North indicator at the absolute top of the circle.
  void _drawNorthArrow(
    Canvas canvas,
    LabelPlacer labels,
    Offset Function(double, double) atPx,
    double outsidePx,
  ) {
    final tail = atPx(0, outsidePx + 8);
    final tip = atPx(0, outsidePx + 44);
    canvas.drawLine(tail, tip, cadStroke(palette.ink, CadWeight.pipe));
    drawArrowHead(canvas, tip, const Offset(0, 1), palette.ink, 9);
    labels.reserve(LabelPlacer.corridor(tail, tip, pad: 6));
    labels.draw(
      canvas,
      'N 0\u00B0',
      tip - const Offset(0, 22),
      11,
      align: LabelAnchor.center,
      bold: true,
      color: palette.ink,
    );
  }

  void _drawPipe(
    Canvas canvas,
    LabelPlacer labels,
    Size size,
    Offset center,
    double Function(double) r,
    Offset Function(double, double) pt,
    PipePenetration pipe,
    double insideR,
    double outsideR,
  ) {
    final conflicted = conflictedPipes.contains(pipe.name);
    final color = conflicted ? palette.conflict : palette.pipe;
    final holeColor = conflicted ? palette.conflict : palette.hole;
    final angle = pipe.normalizedAngleDeg;
    final rad = (angle - 90) * math.pi / 180.0;
    final along = Offset(math.cos(rad), math.sin(rad));
    final across = Offset(-along.dy, along.dx);

    // Directional flow line from the centre out through the wall.
    final tip = pt(angle, outsideR + _stubIn);
    canvas.drawLine(center, tip, cadStroke(color, CadWeight.pipe));
    drawArrowHead(canvas, tip, -along, color, 7);

    // Pipe walls and the cored opening through the barrel wall.
    final halfPipe = r(pipe.outsideDiameterIn / 2);
    final halfHole = r(pipe.holeSizeIn / 2);
    final wallIn = pt(angle, insideR);
    for (final sign in const [-1.0, 1.0]) {
      canvas.drawLine(
        wallIn + across * (halfPipe * sign),
        tip + across * (halfPipe * sign),
        cadStroke(color, CadWeight.hidden),
      );
    }
    final holeOuter = pt(angle, outsideR);
    canvas.drawLine(
      wallIn + across * halfHole,
      holeOuter + across * halfHole,
      cadStroke(holeColor, CadWeight.pipe),
    );
    canvas.drawLine(
      wallIn - across * halfHole,
      holeOuter - across * halfHole,
      cadStroke(holeColor, CadWeight.pipe),
    );

    labels.reserve(LabelPlacer.corridor(center, tip, pad: halfPipe + 2));

    // Angle callout parked outside the barrel on the pipe's own heading.
    final nearNorth = angle < 12 || angle > 348;
    final vertical = nearNorth || (angle > 168 && angle < 192);
    // Near North the callout straddles the fixed North arrow: headings just
    // shy of 360 park to its left, headings just past 0 to its right.
    final onRight = nearNorth ? angle < 12 : angle < 180;
    final anchor = nearNorth
        ? tip + Offset(onRight ? 46 : -46, 10)
        : tip + along * 14;
    final rect = labels.draw(
      canvas,
      '${pipe.name}\n${angle.toStringAsFixed(0)}\u00B0 (${pipe.clockPosition})\n'
      'HOLE ${inchesText(pipe.holeSizeIn)}\u00F8',
      Offset(anchor.dx, anchor.dy - (angle > 90 && angle < 270 ? 2 : 30)),
      8.5,
      align: vertical && angle > 90 && !nearNorth
          ? LabelAnchor.center
          : (onRight ? LabelAnchor.left : LabelAnchor.right),
      color: color,
      maxWidth: math.max(58.0, size.width * 0.18),
    );
    if (!rect.contains(tip)) {
      canvas.drawLine(
        tip,
        Offset(tip.dx < rect.center.dx ? rect.left - 3 : rect.right + 3, rect.center.dy),
        cadStroke(color, CadWeight.dimension),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlanPainter oldDelegate) => true;
}
