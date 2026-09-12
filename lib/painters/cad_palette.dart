import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Blueprint colour scheme for the CAD canvases. Two variants: stark white
/// shop paper, and technical dark slate.
class CadPalette {
  const CadPalette({
    required this.paper,
    required this.ink,
    required this.thinInk,
    required this.concrete,
    required this.concreteDark,
    required this.dimension,
    required this.callout,
    required this.pipe,
    required this.conflict,
  });

  final Color paper;
  final Color ink;
  final Color thinInk;
  final Color concrete;
  final Color concreteDark;
  final Color dimension;
  final Color callout;
  final Color pipe;
  final Color conflict;

  static const light = CadPalette(
    paper: Color(0xFFFDFDFB),
    ink: Color(0xFF10202C),
    thinInk: Color(0xFF7C8B99),
    concrete: Color(0xFFEDEFF1),
    concreteDark: Color(0xFFD8DDE2),
    dimension: Color(0xFF0B6BCB),
    callout: Color(0xFF24323E),
    pipe: Color(0xFF00695C),
    conflict: Color(0xFFD50000),
  );

  static const slate = CadPalette(
    paper: Color(0xFF16222E),
    ink: Color(0xFFE6EDF3),
    thinInk: Color(0xFF7D93A6),
    concrete: Color(0xFF223243),
    concreteDark: Color(0xFF2C3F53),
    dimension: Color(0xFF5BB4FF),
    callout: Color(0xFFD7E3ED),
    pipe: Color(0xFF4DD0B1),
    conflict: Color(0xFFFF5252),
  );
}

/// Draws a dimension line with arrowheads at both ends.
void drawDimensionLine(Canvas canvas, Offset a, Offset b, Color color, {double head = 5}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  canvas.drawLine(a, b, paint);
  final length = (b - a).distance;
  if (length < 1) return;
  final dir = (b - a) / length;
  _arrowHead(canvas, a, dir, color, head);
  _arrowHead(canvas, b, -dir, color, head);
}

/// Extension (witness) line, drawn thin.
void drawExtensionLine(Canvas canvas, Offset a, Offset b, Color color) {
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke,
  );
}

/// Leader line from a callout to the feature it annotates, with one arrowhead.
void drawLeader(Canvas canvas, Offset from, Offset to, Color color) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 0.9
    ..style = PaintingStyle.stroke;
  canvas.drawLine(from, to, paint);
  final length = (to - from).distance;
  if (length < 1) return;
  _arrowHead(canvas, to, (from - to) / length, color, 4);
}

void _arrowHead(Canvas canvas, Offset tip, Offset inward, Color color, double size) {
  final normal = Offset(-inward.dy, inward.dx);
  final base = tip + inward * size;
  final path = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(base.dx + normal.dx * size * 0.38, base.dy + normal.dy * size * 0.38)
    ..lineTo(base.dx - normal.dx * size * 0.38, base.dy - normal.dy * size * 0.38)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Formats inches as feet-inches shop notation, e.g. 10'-6".
String feetInches(double inches) {
  final sign = inches < 0 ? '-' : '';
  final total = inches.abs();
  final feet = total ~/ 12;
  final rem = total - feet * 12;
  final roundedRem = (rem * 100).roundToDouble() / 100;
  final remText = roundedRem == roundedRem.roundToDouble()
      ? roundedRem.toStringAsFixed(0)
      : roundedRem.toStringAsFixed(2);
  return '$sign$feet\'-$remText"';
}

/// Cross-hatch fill used for cut concrete.
void hatchRect(Canvas canvas, Rect rect, Color color, {double spacing = 9}) {
  canvas.save();
  canvas.clipRect(rect);
  final paint = Paint()
    ..color = color
    ..strokeWidth = 0.6;
  final extent = rect.width + rect.height;
  for (var d = -rect.height; d < extent; d += spacing) {
    canvas.drawLine(
      Offset(rect.left + d, rect.top),
      Offset(rect.left + d + rect.height, rect.bottom),
      paint,
    );
  }
  canvas.restore();
}

/// Point on a circle for a clockwise-from-north angle.
Offset polar(Offset center, double radius, double angleDegFromNorth) {
  final rad = (angleDegFromNorth - 90) * math.pi / 180.0;
  return center + Offset(math.cos(rad), math.sin(rad)) * radius;
}
