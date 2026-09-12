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
    required this.hole,
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

  /// Cored / cast opening outline, drawn dashed like the shop submittals.
  final Color hole;
  final Color conflict;

  static const light = CadPalette(
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF000000),
    thinInk: Color(0xFF9AA3AB),
    concrete: Color(0xFFFFFFFF),
    concreteDark: Color(0xFFF2F4F6),
    dimension: Color(0xFF000000),
    callout: Color(0xFF000000),
    pipe: Color(0xFF0F7A6B),
    hole: Color(0xFF1B39C4),
    conflict: Color(0xFFD50000),
  );

  static const slate = CadPalette(
    paper: Color(0xFF16222E),
    ink: Color(0xFFE9F1F7),
    thinInk: Color(0xFF7D93A6),
    concrete: Color(0xFF16222E),
    concreteDark: Color(0xFF20303F),
    dimension: Color(0xFFE9F1F7),
    callout: Color(0xFFE9F1F7),
    pipe: Color(0xFF4DD0B1),
    hole: Color(0xFF7FA6FF),
    conflict: Color(0xFFFF5252),
  );
}

/// Uniform engineering lettering used by every annotation on both sheets.
const List<String> kCadFontFallback = ['Roboto', 'Helvetica', 'Arial', 'sans-serif'];

/// Lettering style shared by every annotation so the sheets read as one
/// uniform engineering font.
TextStyle cadLabelStyle(double fontSize, Color color, {bool bold = false}) => TextStyle(
  fontSize: fontSize,
  color: color,
  height: 1.15,
  letterSpacing: 0.2,
  fontFamilyFallback: kCadFontFallback,
  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
);

/// CAD line weights, in logical pixels at the fixed sheet size.
class CadWeight {
  const CadWeight._();

  /// Cut concrete outline.
  static const double outline = 1.3;

  /// Hidden (bore) and secondary geometry.
  static const double hidden = 0.9;

  /// Dimension, extension and leader lines.
  static const double dimension = 0.7;

  /// Construction geometry: centrelines, joints, clock ticks.
  static const double thin = 0.6;

  /// Pipes and their openings.
  static const double pipe = 1.4;
}

Paint cadStroke(Color color, double width) => Paint()
  ..color = color
  ..strokeWidth = width
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.butt;

/// Draws a dimension line with mechanical arrowheads at both ends.
void drawDimensionLine(Canvas canvas, Offset a, Offset b, Color color, {double head = 5}) {
  final paint = cadStroke(color, CadWeight.dimension);
  canvas.drawLine(a, b, paint);
  final length = (b - a).distance;
  if (length < 1) return;
  final dir = (b - a) / length;
  if (length > head * 2.4) {
    drawArrowHead(canvas, a, dir, color, head);
    drawArrowHead(canvas, b, -dir, color, head);
  } else {
    // Too tight for inward arrowheads: flip them outboard like CAD does.
    drawArrowHead(canvas, a, -dir, color, head);
    drawArrowHead(canvas, b, dir, color, head);
  }
}

/// Extension (witness) line, drawn thin.
void drawExtensionLine(Canvas canvas, Offset a, Offset b, Color color) {
  canvas.drawLine(a, b, cadStroke(color, CadWeight.dimension));
}

/// Leader line from a callout to the feature it annotates, with one arrowhead.
void drawLeader(Canvas canvas, Offset from, Offset to, Color color, {double head = 4.5}) {
  canvas.drawLine(from, to, cadStroke(color, CadWeight.dimension));
  final length = (to - from).distance;
  if (length < 1) return;
  drawArrowHead(canvas, to, (from - to) / length, color, head);
}

/// Solid triangular arrowhead with [tip] pointing away from [inward].
void drawArrowHead(Canvas canvas, Offset tip, Offset inward, Color color, double size) {
  final normal = Offset(-inward.dy, inward.dx);
  final base = tip + inward * size;
  final path = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(base.dx + normal.dx * size * 0.30, base.dy + normal.dy * size * 0.30)
    ..lineTo(base.dx - normal.dx * size * 0.30, base.dy - normal.dy * size * 0.30)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Short witness tick drawn perpendicular to a dimension string.
void drawDimensionTick(Canvas canvas, Offset at, bool vertical, Color color, {double half = 4}) {
  final delta = vertical ? Offset(half, 0) : Offset(0, half);
  canvas.drawLine(at - delta, at + delta, cadStroke(color, CadWeight.dimension));
}

/// Dashed line with a fixed CAD dash pattern.
void drawDashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double dash = 5,
  double gap = 3.5,
}) {
  final total = (b - a).distance;
  if (total <= 0) return;
  final dir = (b - a) / total;
  var travelled = 0.0;
  while (travelled < total) {
    final end = math.min(travelled + dash, total);
    canvas.drawLine(a + dir * travelled, a + dir * end, paint);
    travelled = end + gap;
  }
}

/// Long-dash / dot centreline pattern.
void drawCenterLine(Canvas canvas, Offset a, Offset b, Paint paint) {
  const pattern = [11.0, 3.5, 1.5, 3.5];
  final total = (b - a).distance;
  if (total <= 0) return;
  final dir = (b - a) / total;
  var travelled = 0.0;
  var index = 0;
  while (travelled < total) {
    final length = pattern[index % pattern.length];
    final end = math.min(travelled + length, total);
    if (index.isEven) canvas.drawLine(a + dir * travelled, a + dir * end, paint);
    travelled = end;
    index++;
  }
}

/// Dashed circle, used for cored openings projected onto a view.
void drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
  if (radius <= 0.5) return;
  final step = math.max(0.16, 7 / radius);
  for (var a = 0.0; a < math.pi * 2; a += step * 2) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, a, step, false, paint);
  }
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

/// Inch value written the way MH Pro prints it: whole inches bare, otherwise
/// two decimals.
String inchesText(double inches) => inches == inches.roundToDouble()
    ? inches.toStringAsFixed(0)
    : inches.toStringAsFixed(2);

/// Cross-hatch fill used for cut concrete.
void hatchRect(Canvas canvas, Rect rect, Color color, {double spacing = 9}) {
  canvas.save();
  canvas.clipRect(rect);
  final paint = Paint()
    ..color = color
    ..strokeWidth = 0.5;
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
