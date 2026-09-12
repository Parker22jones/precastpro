import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pipe_penetration.dart';
import '../models/structure_size.dart';
import 'cad_palette.dart';
import 'label_layout.dart';

/// Top-down CAD plan drawn like the shop submittals: the barrel walls (a pair
/// of concentric circles, or a sharp-cornered box), a dashed compass crosshair
/// with a fixed 0 degree North arrow, dimension strings and a directional flow
/// line per penetration labelled with its exact clock angle.
class PlanPainter extends CustomPainter {
  PlanPainter({
    required this.size,
    required this.pipes,
    required this.conflictedPipes,
    this.topOpeningDiameterIn = 24,
    this.palette = CadPalette.light,
    this.title = 'PLAN VIEW',
  });

  /// Plan geometry of the structure: round diameter or box width x length.
  final StructureSize size;

  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;

  /// Access opening of the top set over the barrel, in inches.
  final double topOpeningDiameterIn;
  final CadPalette palette;
  final String title;

  /// Pipe stub length outside the wall, in inches.
  static const double _stubIn = 14;

  double get insideDiameterIn => size.insideDiameterIn;
  double get wallThicknessIn => size.wallThicknessIn;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.drawRect(Offset.zero & canvasSize, Paint()..color = palette.paper);
    final labels = LabelPlacer(canvasSize);

    _drawSheet(canvas, canvasSize, labels);

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2 + 10);
    final margin = math.min(72.0, math.min(canvasSize.width, canvasSize.height) * 0.14);
    final available = math.max(
      math.min(canvasSize.width, canvasSize.height) / 2 - margin,
      18.0,
    );
    final scale = available / (size.outsideHalfDiagonalIn + _stubIn);

    double r(double inches) => inches * scale;
    Offset pt(double angleDeg, double radiusIn) => polar(center, r(radiusIn), angleDeg);
    Offset atPx(double angleDeg, double radiusPx) => polar(center, radiusPx, angleDeg);
    final outsidePx = r(size.outsideHalfDiagonalIn);

    _drawBarrel(canvas, center, r);
    _drawCompass(canvas, labels, center, outsidePx);
    _drawSizeStrings(canvas, labels, center, r);
    _drawNorthArrow(canvas, labels, atPx, r(size.outsideReachIn(0)));

    // Pipe callouts claim their space before the decorative clock labels.
    for (final pipe in pipes) {
      _drawPipe(canvas, labels, canvasSize, center, r, pt, pipe);
    }
    _drawClockTicks(canvas, labels, atPx, outsidePx);

    if (conflictedPipes.isNotEmpty) {
      labels.draw(
        canvas,
        '!! PENETRATION CONFLICT',
        Offset(canvasSize.width - 9, canvasSize.height - 19),
        10.5,
        align: LabelAnchor.right,
        bold: true,
        color: palette.conflict,
        avoidOverlap: false,
      );
    }
  }

  void _drawSheet(Canvas canvas, Size canvasSize, LabelPlacer labels) {
    final border = Rect.fromLTWH(3, 3, canvasSize.width - 6, canvasSize.height - 6);
    canvas.drawRect(border, cadStroke(palette.ink, 1.0));
    canvas.drawLine(
      const Offset(3, 22),
      Offset(canvasSize.width - 3, 22),
      cadStroke(palette.ink, CadWeight.thin),
    );
    labels.draw(canvas, title.toUpperCase(), const Offset(9, 6), 11, bold: true, color: palette.ink);
    labels.draw(
      canvas,
      size.label,
      Offset(canvasSize.width - 9, 7),
      8.5,
      align: LabelAnchor.right,
      color: palette.callout,
    );
    labels.draw(
      canvas,
      'ANGLES CLOCKWISE FROM FIXED 0\u00B0 NORTH',
      Offset(9, canvasSize.height - 18),
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

  /// Rectangle centred on [center], sized by half extents in inches.
  Rect _box(Offset center, double Function(double) r, double halfWidthIn, double halfLengthIn) =>
      Rect.fromCenter(
        center: center,
        width: r(halfWidthIn) * 2,
        height: r(halfLengthIn) * 2,
      );

  void _drawBarrel(Canvas canvas, Offset center, double Function(double) r) {
    final fill = Paint()..color = palette.concrete;
    final outline = cadStroke(palette.ink, CadWeight.outline);
    if (size.isRound) {
      canvas.drawCircle(center, r(size.outsideWidthIn / 2), fill);
      canvas.drawCircle(center, r(size.outsideWidthIn / 2), outline);
      canvas.drawCircle(center, r(size.insideWidthIn / 2), outline);
    } else {
      // Sharp-cornered box: outside face, then the inside face of the walls.
      final outer = _box(center, r, size.outsideWidthIn / 2, size.outsideLengthIn / 2);
      final inner = _box(center, r, size.insideWidthIn / 2, size.insideLengthIn / 2);
      canvas.drawRect(outer, fill);
      canvas.drawRect(outer, outline);
      canvas.drawRect(inner, outline);
    }
    // Access opening of the top, shown lighter as it sits above the barrel.
    final openingR = math.min(topOpeningDiameterIn / 2, size.maxOpeningIn / 2);
    canvas.drawCircle(center, r(openingR), cadStroke(palette.thinInk, CadWeight.hidden));
  }

  /// Dimension strings across the structure, as drawn on the submittals:
  /// a diagonal diameter on a round barrel, width and length on a box.
  void _drawSizeStrings(
    Canvas canvas,
    LabelPlacer labels,
    Offset center,
    double Function(double) r,
  ) {
    void string(Offset a, Offset b, Offset textAt, String text) {
      drawDimensionLine(canvas, a, b, palette.dimension, head: 5);
      labels.reserve(LabelPlacer.corridor(a, b, pad: 3));
      labels.draw(
        canvas,
        text,
        textAt,
        9.5,
        align: LabelAnchor.center,
        color: palette.dimension,
      );
    }

    if (size.isRound) {
      final insideR = size.insideWidthIn / 2;
      void diameter(double angleDeg, double radiusIn, String text) {
        string(
          polar(center, r(radiusIn), angleDeg),
          polar(center, r(radiusIn), angleDeg + 180),
          polar(center, r(radiusIn) * 0.55, angleDeg) + const Offset(0, -16),
          text,
        );
      }

      diameter(48, insideR, '${inchesText(size.insideDiameterIn)}\u00F8');
      final openingR = math.min(topOpeningDiameterIn / 2, insideR);
      if (openingR < insideR - 1) {
        diameter(132, openingR, '${inchesText(openingR * 2)}\u00F8');
      }
      return;
    }

    final inner = _box(center, r, size.insideWidthIn / 2, size.insideLengthIn / 2);
    // Inside width across the box, read east-west.
    string(
      Offset(inner.left, inner.center.dy),
      Offset(inner.right, inner.center.dy),
      Offset(inner.center.dx, inner.center.dy - 30),
      '${inchesText(size.insideWidthIn)} W',
    );
    // Inside length down the box, read north-south.
    string(
      Offset(inner.center.dx, inner.top),
      Offset(inner.center.dx, inner.bottom),
      Offset(inner.center.dx + 40, inner.center.dy + 12),
      '${inchesText(size.insideLengthIn)} L',
    );
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
    Size canvasSize,
    Offset center,
    double Function(double) r,
    Offset Function(double, double) pt,
    PipePenetration pipe,
  ) {
    final conflicted = conflictedPipes.contains(pipe.name);
    final color = conflicted ? palette.conflict : palette.pipe;
    final holeColor = conflicted ? palette.conflict : palette.hole;
    final angle = pipe.normalizedAngleDeg;
    final insideR = size.insideReachIn(angle);
    final outsideR = size.outsideReachIn(angle);
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

    // On a box the opening is cut in a flat face, so a skewed pipe stretches
    // the cut along that face: mark the cut on both wall faces to scale.
    final face = size.wallFaceFor(angle);
    final cutWidthIn = face == null ? 0.0 : size.wallCutWidthIn(pipe.holeSizeIn, angle);
    if (face != null) {
      final faceDir = face.isEastWest ? const Offset(0, 1) : const Offset(1, 0);
      final halfCut = r(cutWidthIn / 2);
      final cut = cadStroke(holeColor, CadWeight.outline);
      canvas.drawLine(wallIn - faceDir * halfCut, wallIn + faceDir * halfCut, cut);
      canvas.drawLine(holeOuter - faceDir * halfCut, holeOuter + faceDir * halfCut, cut);
    }

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
      'HOLE ${inchesText(pipe.holeSizeIn)}\u00F8'
      '${face == null ? '' : '\n${face.label} CUT ${inchesText(cutWidthIn)} '
                '@ ${size.skewDegFor(angle).toStringAsFixed(0)}\u00B0 SKEW'}',
      Offset(anchor.dx, anchor.dy - (angle > 90 && angle < 270 ? 2 : 30)),
      8.5,
      align: vertical && angle > 90 && !nearNorth
          ? LabelAnchor.center
          : (onRight ? LabelAnchor.left : LabelAnchor.right),
      color: color,
      maxWidth: math.max(58.0, canvasSize.width * 0.18),
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
