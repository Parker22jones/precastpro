import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/structure_layout.dart';
import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';
import 'label_layout.dart';

/// Scaled side profile of the stacked structure with seams and pipe entries.
class ElevationPainter extends CustomPainter {
  ElevationPainter({
    required this.layout,
    required this.pipes,
    required this.conflictedPipes,
    this.background = Colors.white,
  });

  final StructureLayout layout;
  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;
  final Color background;

  static const _concrete = Color(0xFFD7D3CC);
  static const _concreteDark = Color(0xFFBDB8B0);
  static const _outline = Color(0xFF37474F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final labels = LabelPlacer(size);

    final bottomElev = layout.floorBottomElevationFt;
    final topElev = math.max(layout.topOfStackElevationFt, bottomElev + 1);
    final elevSpan = topElev - bottomElev;

    const marginTop = 28.0;
    const marginBottom = 34.0;
    const marginLeft = 74.0;
    const marginRight = 96.0;

    final drawH = math.max(size.height - marginTop - marginBottom, 20.0);
    final drawW = math.max(size.width - marginLeft - marginRight, 20.0);

    // Widest element governs the horizontal scale (pipes stick out 10").
    final widestIn = layout.outsideDiameterIn + 20;
    final scale = math.min(drawH / (elevSpan * 12), drawW / widestIn);

    final centerX = marginLeft + drawW / 2;
    double y(double elevFt) => marginTop + (topElev - elevFt) * 12 * scale;
    double x(double inchesFromCenter) => centerX + inchesFromCenter * scale;

    _drawTitle(labels, canvas, size, 'ELEVATION VIEW', scale);

    // 8" base floor.
    final floorHalf = layout.outsideDiameterIn / 2;
    final floorRect = Rect.fromLTRB(
      x(-floorHalf),
      y(layout.floorTopElevationFt),
      x(floorHalf),
      y(layout.floorBottomElevationFt),
    );
    canvas.drawRect(floorRect, Paint()..color = _concreteDark);
    canvas.drawRect(floorRect, _stroke(_outline, 1.4));
    labels.draw(canvas, '8" BASE FLOOR', Offset(x(floorHalf) + 6, floorRect.center.dy - 6), 9,
        color: const Color(0xFF546E7A));

    // Stacked pieces.
    for (final laid in layout.pieces) {
      final p = laid.piece;
      final halfOut = p.type == PieceType.gradeRing
          ? (p.insideDiameterIn / 2 + p.wallThicknessIn)
          : p.outsideDiameterIn / 2;
      final halfIn = p.insideDiameterIn / 2;
      final top = y(laid.topElevationFt);
      final bottom = y(laid.bottomElevationFt);

      if (p.type == PieceType.conicalTop) {
        final topHalfOut = (p.topOpeningDiameterIn ?? 24) / 2 + p.wallThicknessIn;
        final path = Path()
          ..moveTo(x(-halfOut), bottom)
          ..lineTo(x(-halfOut), bottom - (bottom - top) * 0.08)
          ..lineTo(x(-topHalfOut), top)
          ..lineTo(x(topHalfOut), top)
          ..lineTo(x(halfOut), bottom - (bottom - top) * 0.08)
          ..lineTo(x(halfOut), bottom)
          ..close();
        canvas.drawPath(path, Paint()..color = _concrete);
        canvas.drawPath(path, _stroke(_outline, 1.4));
      } else {
        final rect = Rect.fromLTRB(x(-halfOut), top, x(halfOut), bottom);
        canvas.drawRect(rect, Paint()..color = _concrete);
        canvas.drawRect(rect, _stroke(_outline, 1.4));
        if (p.type != PieceType.gradeRing) {
          // Inside face lines.
          canvas.drawLine(Offset(x(-halfIn), top), Offset(x(-halfIn), bottom), _stroke(_concreteDark, 1));
          canvas.drawLine(Offset(x(halfIn), top), Offset(x(halfIn), bottom), _stroke(_concreteDark, 1));
        }
        if (p.type == PieceType.flatTop) {
          final oHalf = (p.topOpeningDiameterIn ?? 24) / 2;
          final opening = Rect.fromLTRB(x(-oHalf), top, x(oHalf), bottom);
          canvas.drawRect(opening, Paint()..color = background);
          canvas.drawRect(opening, _stroke(_outline, 1.0));
        }
      }

      if ((bottom - top).abs() > 11) {
        labels.draw(
          canvas,
          p.description,
          Offset(x(-halfOut) - 6, (top + bottom) / 2 - 5),
          8.5,
          align: LabelAnchor.right,
          color: const Color(0xFF37474F),
        );
      }
    }

    // Seam (joint) lines.
    final seamPaint = _stroke(const Color(0xFF1565C0), 1.0);
    for (final elev in layout.jointElevationsFt) {
      final yy = y(elev);
      _dashedLine(canvas, Offset(x(-layout.outsideDiameterIn / 2) - 10, yy),
          Offset(x(layout.outsideDiameterIn / 2) + 10, yy), seamPaint);
    }

    // Rim and invert reference lines.
    _referenceLine(labels, canvas, y(layout.rimElevationFt), x(-layout.outsideDiameterIn / 2) - 16,
        x(layout.outsideDiameterIn / 2) + 84, 'RIM ${layout.rimElevationFt.toStringAsFixed(2)}');
    _referenceLine(labels, canvas, y(layout.invertElevationFt), x(-layout.outsideDiameterIn / 2) - 16,
        x(layout.outsideDiameterIn / 2) + 84, 'INV ${layout.invertElevationFt.toStringAsFixed(2)}');

    // Pipe penetrations.
    for (final pipe in pipes) {
      final onRight = pipe.normalizedAngleDeg <= 180;
      final conflicted = conflictedPipes.contains(pipe.name);
      final color = conflicted ? const Color(0xFFD50000) : const Color(0xFF00695C);
      final yInv = y(pipe.invertElevationFt);
      final yCrown = y(pipe.invertElevationFt + pipe.outsideDiameterIn / 12);
      final wallX = x(onRight ? layout.outsideDiameterIn / 2 : -layout.outsideDiameterIn / 2);
      final outX = wallX + (onRight ? 34.0 : -34.0);

      final pipeRect = Rect.fromLTRB(
        math.min(wallX, outX),
        yCrown,
        math.max(wallX, outX),
        yInv,
      );
      canvas.drawRect(pipeRect, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawRect(pipeRect, _stroke(color, 1.6));
      _dashedLine(canvas, Offset(x(-layout.outsideDiameterIn / 2) - 4, yInv),
          Offset(x(layout.outsideDiameterIn / 2) + 4, yInv), _stroke(color, 1.0));

      labels.draw(
        canvas,
        '${pipe.name}  ${pipe.outsideDiameterIn.toStringAsFixed(1)}" OD\n'
        'INV ${pipe.invertElevationFt.toStringAsFixed(2)}  @ ${pipe.clockPosition}',
        Offset(onRight ? outX + 5 : outX - 5, (yCrown + yInv) / 2 - 12),
        8.5,
        align: onRight ? LabelAnchor.left : LabelAnchor.right,
        color: color,
      );
    }

    _drawScaleBar(labels, canvas, size, scale);
  }

  void _drawTitle(LabelPlacer labels, Canvas canvas, Size size, String title, double scale) {
    labels.draw(canvas, title, const Offset(10, 6), 12, bold: true, color: const Color(0xFF263238));
    labels.draw(canvas, 'SCALE 1" = ${(1 / (scale * 12)).toStringAsFixed(2)}\'',
        Offset(size.width - 10, 6), 9,
        align: LabelAnchor.right, color: const Color(0xFF607D8B));
  }

  void _drawScaleBar(LabelPlacer labels, Canvas canvas, Size size, double scale) {
    final barLen = 12 * scale; // one foot
    final y0 = size.height - 16;
    final x0 = 12.0;
    final paint = _stroke(const Color(0xFF263238), 1.4);
    canvas.drawLine(Offset(x0, y0), Offset(x0 + barLen, y0), paint);
    canvas.drawLine(Offset(x0, y0 - 4), Offset(x0, y0 + 4), paint);
    canvas.drawLine(Offset(x0 + barLen, y0 - 4), Offset(x0 + barLen, y0 + 4), paint);
    labels.draw(canvas, "1'-0\"", Offset(x0 + barLen + 6, y0 - 6), 8.5,
        color: const Color(0xFF455A64), avoidOverlap: false);
  }

  void _referenceLine(
      LabelPlacer labels, Canvas canvas, double yy, double x0, double x1, String text) {
    final paint = _stroke(const Color(0xFF455A64), 1.0);
    _dashedLine(canvas, Offset(x0, yy), Offset(x1, yy), paint);
    labels.draw(canvas, text, Offset(x1 + 2, yy - 10), 9,
        align: LabelAnchor.right, color: const Color(0xFF263238));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
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

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(covariant ElevationPainter oldDelegate) => true;
}

/// Renders a painter to a PNG so the same drawing can be embedded in the PDF.
Future<Uint8List> renderPainterToPng(
  CustomPainter painter,
  Size size, {
  double pixelRatio = 2.5,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * pixelRatio).round(),
    (size.height * pixelRatio).round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
