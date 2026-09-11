import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Horizontal anchoring of a drawing annotation relative to its anchor point.
enum LabelAnchor { left, right, center }

/// Places drawing annotations so they stay inside the canvas and do not
/// overlap annotations already drawn on the same canvas.
///
/// The painters share this because the PDF export rasterises the very same
/// painters at a different aspect ratio, where unclamped text falls outside
/// the image bounds.
class LabelPlacer {
  LabelPlacer(this.size);

  final Size size;
  final List<Rect> _placed = <Rect>[];

  static const double _padding = 2.0;
  static const double _spacing = 2.0;

  void draw(
    Canvas canvas,
    String text,
    Offset anchor,
    double fontSize, {
    LabelAnchor align = LabelAnchor.left,
    bool bold = false,
    Color color = Colors.black,
    bool avoidOverlap = true,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      ),
    );
    final measured = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    // Lay the final painter out at its intrinsic width — capped to the canvas so
    // long annotations wrap instead of running off a narrow drawing.
    final width = math.min(measured.width, math.max(24.0, size.width - 2 * _padding));
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: align == LabelAnchor.right
          ? TextAlign.right
          : align == LabelAnchor.center
              ? TextAlign.center
              : TextAlign.left,
    )..layout(minWidth: width, maxWidth: width);

    final dx = switch (align) {
      LabelAnchor.left => anchor.dx,
      LabelAnchor.right => anchor.dx - painter.width,
      LabelAnchor.center => anchor.dx - painter.width / 2,
    };
    var rect = _clamp(Rect.fromLTWH(dx, anchor.dy, painter.width, painter.height));
    if (avoidOverlap) rect = _resolve(rect);

    painter.paint(canvas, rect.topLeft);
    _placed.add(rect);
  }

  Rect _clamp(Rect rect) {
    final maxLeft = math.max(_padding, size.width - rect.width - _padding);
    final maxTop = math.max(_padding, size.height - rect.height - _padding);
    return Rect.fromLTWH(
      rect.left.clamp(_padding, maxLeft),
      rect.top.clamp(_padding, maxTop),
      rect.width,
      rect.height,
    );
  }

  /// Nudges the label vertically (down first, then up) until it clears the
  /// annotations already on the canvas.
  Rect _resolve(Rect rect) {
    for (final direction in const [1.0, -1.0]) {
      var candidate = rect;
      for (var attempt = 0; attempt < 24; attempt++) {
        final hit = _firstHit(candidate);
        if (hit == null) return candidate;
        final shifted = direction > 0
            ? candidate.top + (hit.bottom - candidate.top) + _spacing
            : candidate.top - ((candidate.bottom - hit.top) + _spacing);
        if (shifted < _padding || shifted + candidate.height > size.height - _padding) break;
        candidate = Rect.fromLTWH(candidate.left, shifted, candidate.width, candidate.height);
      }
    }
    return rect;
  }

  Rect? _firstHit(Rect rect) {
    for (final other in _placed) {
      if (rect.overlaps(other.inflate(_spacing / 2))) return other;
    }
    return null;
  }
}
