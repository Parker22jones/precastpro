import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/structure_layout.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';
import 'cad_palette.dart';
import 'label_layout.dart';

/// Scaled CAD elevation of the stacked structure: sharp vector outlines,
/// hatched concrete, dimension strings with arrowheads and leader callouts for
/// every piece seam and pipe penetration.
class ElevationPainter extends CustomPainter {
  ElevationPainter({
    required this.layout,
    required this.pipes,
    required this.conflictedPipes,
    this.palette = CadPalette.light,
    this.title = 'ELEVATION VIEW',
  });

  final StructureLayout layout;
  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;
  final CadPalette palette;
  final String title;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
    final labels = LabelPlacer(size);

    final bottomElev = layout.floorBottomElevationFt;
    final topElev = math.max(layout.topOfStackElevationFt, bottomElev + 1);
    final elevSpan = topElev - bottomElev;

    const marginTop = 38.0;
    const marginBottom = 34.0;
    const marginLeft = 150.0;
    const marginRight = 152.0;

    final drawH = math.max(size.height - marginTop - marginBottom, 20.0);
    final drawW = math.max(size.width - marginLeft - marginRight, 20.0);

    // Widest element governs the horizontal scale (pipes stick out 10").
    final widestIn = layout.outsideDiameterIn + 20;
    final scale = math.min(drawH / (elevSpan * 12), drawW / widestIn);

    final centerX = marginLeft + drawW / 2;
    double y(double elevFt) => marginTop + (topElev - elevFt) * 12 * scale;
    double x(double inchesFromCenter) => centerX + inchesFromCenter * scale;

    _drawFrame(canvas, size, labels, scale);

    // Structure centreline.
    _dashDot(
      canvas,
      Offset(centerX, marginTop - 8),
      Offset(centerX, size.height - marginBottom + 6),
      _stroke(palette.thinInk, 0.8),
    );

    // 8" base floor / sump slab.
    final floorHalf = layout.outsideDiameterIn / 2;
    final floorRect = Rect.fromLTRB(
      x(-floorHalf),
      y(layout.floorTopElevationFt),
      x(floorHalf),
      y(layout.floorBottomElevationFt),
    );
    canvas.drawRect(floorRect, Paint()..color = palette.concreteDark);
    hatchRect(canvas, floorRect, palette.thinInk, spacing: 7);
    canvas.drawRect(floorRect, _stroke(palette.ink, 1.4));
    labels.draw(
      canvas,
      '8" BASE FLOOR',
      Offset(x(floorHalf) + 8, floorRect.center.dy - 5),
      9,
      color: palette.callout,
    );

    // Reserve the pipe openings first so piece, seam and datum callouts drawn
    // later are nudged clear of them.
    for (final pipe in pipes) {
      final onRight = pipe.normalizedAngleDeg < 180;
      final wallX = x(onRight ? layout.outsideDiameterIn / 2 : -layout.outsideDiameterIn / 2);
      final outX = wallX + (onRight ? 34.0 : -34.0);
      labels.reserve(
        Rect.fromLTRB(
          math.min(wallX, outX),
          y(pipe.invertElevationFt + pipe.outsideDiameterIn / 12),
          math.max(wallX, outX),
          y(pipe.invertElevationFt),
        ).inflate(5),
      );
    }

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
        final shoulder = bottom - (bottom - top) * 0.08;
        final left = Path()
          ..moveTo(x(-halfOut), bottom)
          ..lineTo(x(-halfOut), shoulder)
          ..lineTo(x(-topHalfOut), top)
          ..lineTo(x(-topHalfOut + p.wallThicknessIn), top)
          ..lineTo(x(-halfIn), shoulder)
          ..lineTo(x(-halfIn), bottom)
          ..close();
        final right = Path()
          ..moveTo(x(halfOut), bottom)
          ..lineTo(x(halfOut), shoulder)
          ..lineTo(x(topHalfOut), top)
          ..lineTo(x(topHalfOut - p.wallThicknessIn), top)
          ..lineTo(x(halfIn), shoulder)
          ..lineTo(x(halfIn), bottom)
          ..close();
        for (final path in [left, right]) {
          canvas.drawPath(path, Paint()..color = palette.concrete);
          canvas.save();
          canvas.clipPath(path);
          hatchRect(canvas, path.getBounds(), palette.thinInk.withValues(alpha: 0.45));
          canvas.restore();
          canvas.drawPath(path, _stroke(palette.ink, 1.4));
        }
      } else {
        final rect = Rect.fromLTRB(x(-halfOut), top, x(halfOut), bottom);
        canvas.drawRect(rect, Paint()..color = palette.concrete);
        if (p.type != PieceType.gradeRing) {
          final leftWall = Rect.fromLTRB(x(-halfOut), top, x(-halfIn), bottom);
          final rightWall = Rect.fromLTRB(x(halfIn), top, x(halfOut), bottom);
          canvas.drawRect(
            Rect.fromLTRB(x(-halfIn), top, x(halfIn), bottom),
            Paint()..color = palette.paper,
          );
          for (final wall in [leftWall, rightWall]) {
            hatchRect(canvas, wall, palette.thinInk.withValues(alpha: 0.55));
            canvas.drawRect(wall, _stroke(palette.ink, 1.1));
          }
          if (p.type == PieceType.flatTop) {
            final oHalf = (p.topOpeningDiameterIn ?? 24) / 2;
            final slabLeft = Rect.fromLTRB(x(-halfIn), top, x(-oHalf), bottom);
            final slabRight = Rect.fromLTRB(x(oHalf), top, x(halfIn), bottom);
            for (final slab in [slabLeft, slabRight]) {
              canvas.drawRect(slab, Paint()..color = palette.concrete);
              hatchRect(canvas, slab, palette.thinInk.withValues(alpha: 0.55));
              canvas.drawRect(slab, _stroke(palette.ink, 1.1));
            }
          }
        } else {
          hatchRect(canvas, rect, palette.thinInk.withValues(alpha: 0.55), spacing: 6);
        }
        canvas.drawRect(rect, _stroke(palette.ink, 1.4));
      }

      // Piece height dimension, left of the structure.
      final dimX = marginLeft - 34;
      if ((bottom - top).abs() > 13) {
        drawExtensionLine(canvas, Offset(x(-halfOut), top), Offset(dimX - 4, top), palette.thinInk);
        drawExtensionLine(
          canvas,
          Offset(x(-halfOut), bottom),
          Offset(dimX - 4, bottom),
          palette.thinInk,
        );
        drawDimensionLine(canvas, Offset(dimX, top), Offset(dimX, bottom), palette.dimension);
        labels.draw(
          canvas,
          feetInches(p.heightIn),
          Offset(dimX - 6, (top + bottom) / 2 - 6),
          8.5,
          align: LabelAnchor.right,
          color: palette.dimension,
        );
      }

      if ((bottom - top).abs() > 11) {
        labels.draw(
          canvas,
          p.description.toUpperCase(),
          Offset(x(halfOut) + 8, (top + bottom) / 2 - 5),
          8.5,
          color: palette.callout,
          maxWidth: 120,
        );
      }
    }

    // Seam (joint) callouts.
    final seamPaint = _stroke(palette.dimension, 1.0);
    var seamIndex = 1;
    for (final elev in layout.jointElevationsFt) {
      final yy = y(elev);
      final left = x(-layout.outsideDiameterIn / 2) - 14;
      final right = x(layout.outsideDiameterIn / 2) + 14;
      _dashedLine(canvas, Offset(left, yy), Offset(right, yy), seamPaint);
      canvas.drawCircle(Offset(right, yy), 2.2, Paint()..color = palette.dimension);
      labels.draw(
        canvas,
        'SEAM ${seamIndex++} EL ${elev.toStringAsFixed(2)}',
        Offset(right + 6, yy - 5),
        8,
        color: palette.dimension,
      );
    }

    // Overall structural depth dimension, far left, labelled above the string
    // so it never collides with the per-piece dimensions.
    final overallX = 14.0;
    final yTopStack = y(layout.topOfStackElevationFt);
    final yBottom = y(layout.floorBottomElevationFt);
    drawDimensionLine(
      canvas,
      Offset(overallX, yTopStack),
      Offset(overallX, yBottom),
      palette.dimension,
    );
    labels.reserve(LabelPlacer.corridor(Offset(overallX, yTopStack), Offset(overallX, yBottom)));
    labels.draw(
      canvas,
      'OVERALL ${feetInches((layout.topOfStackElevationFt - layout.floorBottomElevationFt) * 12)}',
      Offset(overallX, yTopStack - 16),
      8.5,
      color: palette.dimension,
    );

    // Rim / invert reference datums.
    _referenceLine(
      labels,
      canvas,
      y(layout.rimElevationFt),
      x(-layout.outsideDiameterIn / 2) - 18,
      x(layout.outsideDiameterIn / 2) + 70,
      'RIM EL ${layout.rimElevationFt.toStringAsFixed(2)}',
    );
    _referenceLine(
      labels,
      canvas,
      y(layout.invertElevationFt),
      x(-layout.outsideDiameterIn / 2) - 18,
      x(layout.outsideDiameterIn / 2) + 70,
      'INV EL ${layout.invertElevationFt.toStringAsFixed(2)}',
    );
    if (layout.sumpDepthIn > 0) {
      _referenceLine(
        labels,
        canvas,
        y(layout.sumpFloorElevationFt),
        x(-layout.outsideDiameterIn / 2) - 18,
        x(layout.outsideDiameterIn / 2) + 70,
        'SUMP ${feetInches(layout.sumpDepthIn)} BELOW INV',
      );
    }

    // Pipe penetrations.
    for (final pipe in pipes) {
      final onRight = pipe.normalizedAngleDeg < 180;
      final conflicted = conflictedPipes.contains(pipe.name);
      final color = conflicted ? palette.conflict : palette.pipe;
      final yInv = y(pipe.invertElevationFt);
      final yCrown = y(pipe.invertElevationFt + pipe.outsideDiameterIn / 12);
      final wallX = x(onRight ? layout.outsideDiameterIn / 2 : -layout.outsideDiameterIn / 2);
      final outX = wallX + (onRight ? 34.0 : -34.0);

      final pipeRect = Rect.fromLTRB(math.min(wallX, outX), yCrown, math.max(wallX, outX), yInv);
      canvas.drawRect(pipeRect, Paint()..color = color.withValues(alpha: 0.14));
      canvas.drawRect(pipeRect, _stroke(color, 1.6));
      _dashDot(
        canvas,
        Offset(pipeRect.left - 6, pipeRect.center.dy),
        Offset(pipeRect.right + 6, pipeRect.center.dy),
        _stroke(color, 0.8),
      );
      _dashedLine(
        canvas,
        Offset(x(-layout.outsideDiameterIn / 2) - 4, yInv),
        Offset(x(layout.outsideDiameterIn / 2) + 4, yInv),
        _stroke(color, 1.0),
      );

      // Callout sits in the sheet margin with a leader back to the opening.
      final rect = labels.draw(
        canvas,
        '${pipe.name} ${pipe.outsideDiameterIn.toStringAsFixed(1)}" OD ${pipe.material.label}\n'
        'INV ${pipe.invertElevationFt.toStringAsFixed(2)}  '
        '${pipe.normalizedAngleDeg.toStringAsFixed(0)}\u00B0 FROM NORTH (${pipe.clockPosition})',
        Offset(onRight ? size.width - marginRight + 8 : marginLeft - 56, (yCrown + yInv) / 2 - 12),
        8.5,
        align: onRight ? LabelAnchor.left : LabelAnchor.right,
        color: color,
        maxWidth: 90,
      );
      canvas.drawLine(
        Offset(onRight ? pipeRect.right : pipeRect.left, pipeRect.center.dy),
        Offset(onRight ? rect.left - 4 : rect.right + 4, rect.center.dy),
        _stroke(color, 0.8),
      );
    }

    _drawScaleBar(labels, canvas, size, scale);
  }

  void _drawFrame(Canvas canvas, Size size, LabelPlacer labels, double scale) {
    final border = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawRect(border, _stroke(palette.ink, 1.2));
    canvas.drawLine(Offset(3, 22), Offset(size.width - 3, 22), _stroke(palette.thinInk, 0.8));
    labels.draw(canvas, title, const Offset(9, 6), 11.5, bold: true, color: palette.ink);
    labels.draw(
      canvas,
      'SCALE 1" = ${(1 / (scale * 12)).toStringAsFixed(2)}\'',
      Offset(size.width - 9, 6),
      9,
      align: LabelAnchor.right,
      color: palette.thinInk,
    );
  }

  void _drawScaleBar(LabelPlacer labels, Canvas canvas, Size size, double scale) {
    final barLen = 12 * scale; // one foot
    final y0 = size.height - 16;
    const x0 = 12.0;
    final paint = _stroke(palette.ink, 1.4);
    canvas.drawLine(Offset(x0, y0), Offset(x0 + barLen, y0), paint);
    canvas.drawLine(Offset(x0, y0 - 4), Offset(x0, y0 + 4), paint);
    canvas.drawLine(Offset(x0 + barLen, y0 - 4), Offset(x0 + barLen, y0 + 4), paint);
    labels.draw(
      canvas,
      "1'-0\"",
      Offset(x0 + barLen + 6, y0 - 6),
      8.5,
      color: palette.thinInk,
      avoidOverlap: false,
    );
  }

  void _referenceLine(
    LabelPlacer labels,
    Canvas canvas,
    double yy,
    double x0,
    double x1,
    String text,
  ) {
    final paint = _stroke(palette.thinInk, 1.0);
    _dashDot(canvas, Offset(x0, yy), Offset(x1, yy), paint);
    labels.draw(canvas, text, Offset(x1 + 4, yy - 10), 9, color: palette.callout, maxWidth: 104);
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

  /// Long-dash / dot centreline pattern.
  void _dashDot(Canvas canvas, Offset a, Offset b, Paint paint) {
    const pattern = [10.0, 3.0, 1.5, 3.0];
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
