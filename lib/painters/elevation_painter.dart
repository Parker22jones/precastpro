import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/structure_layout.dart';
import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';
import 'cad_palette.dart';
import 'label_layout.dart';

/// Scaled CAD elevation of the stacked structure drawn the way the shop
/// submittals read: a sharp single-weight outline, hidden bore lines, joint
/// lines at every ring seam, a vertical dimension chain with mechanical
/// arrowheads on the left, lettered leader callouts on the right and the
/// penetrations projected onto the section plane.
class ElevationPainter extends CustomPainter {
  ElevationPainter({
    required this.layout,
    required this.pipes,
    required this.conflictedPipes,
    this.palette = CadPalette.light,
    this.title = 'ELEVATION VIEW',
    this.castingLabel,
    this.castingClearOpeningIn = 24,
  });

  final StructureLayout layout;
  final List<PipePenetration> pipes;
  final Set<String> conflictedPipes;
  final CadPalette palette;
  final String title;

  /// Frame and cover set on top of the stack, drawn as a symbol only.
  final String? castingLabel;
  final double castingClearOpeningIn;

  /// Height of the frame-and-cover symbol, in inches.
  static const double _castingSymbolHeightIn = 7;

  /// How far a pipe stub runs outside the wall, in inches.
  static const double _pipeStubIn = 10;

  /// Diameter symbol on round structures; box dimensions read plain.
  String _across(double inches) =>
      layout.isRound ? '${inchesText(inches)}\u00F8' : inchesText(inches);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
    final labels = LabelPlacer(size);

    final marginLeft = math.min(136.0, size.width * 0.26);
    final marginRight = math.min(132.0, size.width * 0.24);
    final marginTop = math.min(62.0, size.height * 0.11);
    final marginBottom = math.min(64.0, size.height * 0.11);

    final drawH = math.max(size.height - marginTop - marginBottom, 20.0);
    final drawW = math.max(size.width - marginLeft - marginRight, 20.0);

    final bottomElev = layout.floorBottomElevationFt;
    final topElev = math.max(
      layout.topOfStackElevationFt + _castingSymbolHeightIn / 12,
      bottomElev + 0.5,
    );
    final elevSpan = topElev - bottomElev;

    // Stubs are allowed to run into the annotation margin, so only a little
    // slack is reserved beside the barrel when fitting the sheet.
    final widestIn = layout.outsideDiameterIn + 20;
    final scale = math.min(drawH / (elevSpan * 12), drawW / widestIn);

    final centerX = marginLeft + drawW / 2;
    // Centre the structure in the sheet when the horizontal fit governs.
    final topOffset = marginTop + (drawH - elevSpan * 12 * scale) / 2;
    double y(double elevFt) => topOffset + (topElev - elevFt) * 12 * scale;
    double x(double inchesFromCenter) => centerX + inchesFromCenter * scale;

    _drawFrame(canvas, size, labels, scale);

    final geometry = _Geometry(layout: layout, x: x, y: y, centerX: centerX);

    drawCenterLine(
      canvas,
      Offset(centerX, y(topElev) - 6),
      Offset(centerX, y(bottomElev) + 10),
      cadStroke(palette.thinInk, CadWeight.thin),
    );

    _reservePipeZones(labels, geometry, x, y);
    _drawStructure(canvas, geometry, x, y);
    _drawCasting(canvas, labels, x, y);
    _drawJoints(canvas, geometry, x, y);
    _drawHeightChain(canvas, labels, geometry, size, marginLeft, x, y);
    _drawWidthDimensions(canvas, labels, geometry, x, y);
    _drawPieceCallouts(canvas, labels, geometry, size, marginRight, x, y);
    _drawPipes(canvas, labels, size, marginLeft, marginRight, x, y);
    _drawScaleBar(labels, canvas, size, scale);
  }

  // --------------------------------------------------------------- structure

  void _drawStructure(Canvas canvas, _Geometry g, _Map x, _Map y) {
    final outline = Path();
    final left = g.leftProfile();
    outline.moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      outline.lineTo(p.dx, p.dy);
    }
    for (final p in left.reversed) {
      outline.lineTo(g.mirror(p).dx, g.mirror(p).dy);
    }
    outline.close();

    canvas.drawPath(outline, Paint()..color = palette.concrete);
    canvas.drawPath(outline, cadStroke(palette.ink, CadWeight.outline));

    // Base floor slab: its top face is a solid cut line across the barrel.
    final floorHalf = layout.outsideDiameterIn / 2;
    canvas.drawLine(
      Offset(x(-floorHalf), y(layout.floorTopElevationFt)),
      Offset(x(floorHalf), y(layout.floorTopElevationFt)),
      cadStroke(palette.ink, CadWeight.outline),
    );

    // Hidden bore: the inside faces of every ring, dashed like a CAD section.
    final hidden = cadStroke(palette.ink, CadWeight.hidden);
    for (final laid in layout.pieces) {
      final piece = laid.piece;
      final top = y(laid.topElevationFt);
      final bottom = y(laid.bottomElevationFt);
      final halfIn = piece.insideDiameterIn / 2;

      switch (piece.type) {
        case PieceType.conicalTop:
          final shoulder = y(g.shoulderElevationFt(laid));
          final openingHalf = (piece.topOpeningDiameterIn ?? castingClearOpeningIn) / 2;
          for (final sign in const [-1.0, 1.0]) {
            drawDashedLine(
              canvas,
              Offset(x(sign * halfIn), bottom),
              Offset(x(sign * halfIn), shoulder),
              hidden,
            );
            drawDashedLine(
              canvas,
              Offset(x(sign * halfIn), shoulder),
              Offset(x(sign * openingHalf), top),
              hidden,
            );
          }
        case PieceType.flatTop:
          final openingHalf = (piece.topOpeningDiameterIn ?? castingClearOpeningIn) / 2;
          for (final sign in const [-1.0, 1.0]) {
            drawDashedLine(
              canvas,
              Offset(x(sign * halfIn), bottom),
              Offset(x(sign * halfIn), top),
              hidden,
            );
            canvas.drawLine(
              Offset(x(sign * halfIn), top),
              Offset(x(sign * openingHalf), top),
              cadStroke(palette.ink, CadWeight.outline),
            );
            canvas.drawLine(
              Offset(x(sign * openingHalf), top),
              Offset(x(sign * openingHalf), bottom),
              cadStroke(palette.ink, CadWeight.outline),
            );
          }
        case PieceType.base:
        case PieceType.riser:
        case PieceType.gradeRing:
          for (final sign in const [-1.0, 1.0]) {
            drawDashedLine(
              canvas,
              Offset(x(sign * halfIn), bottom),
              Offset(x(sign * halfIn), top),
              hidden,
            );
          }
      }
    }
  }

  void _drawJoints(Canvas canvas, _Geometry g, _Map x, _Map y) {
    final paint = cadStroke(palette.ink, CadWeight.thin);
    for (var i = 0; i < layout.pieces.length - 1; i++) {
      final half = math.min(g.halfOutOf(layout.pieces[i].piece), g.halfOutOf(layout.pieces[i + 1].piece));
      final yy = y(layout.pieces[i].topElevationFt);
      canvas.drawLine(Offset(x(-half), yy), Offset(x(half), yy), paint);
    }
  }

  void _drawCasting(Canvas canvas, LabelPlacer labels, _Map x, _Map y) {
    final seat = layout.topOfStackElevationFt;
    final top = seat + _castingSymbolHeightIn / 12;
    final clearHalf = castingClearOpeningIn / 2;
    final flangeHalf = clearHalf + 4;
    final coverTop = y(top);
    final coverBottom = y(top - 2 / 12);

    // Frame: flared seat under a solid cover bar.
    final frame = Path()
      ..moveTo(x(-flangeHalf), y(seat))
      ..lineTo(x(-flangeHalf), coverBottom)
      ..lineTo(x(flangeHalf), coverBottom)
      ..lineTo(x(flangeHalf), y(seat))
      ..lineTo(x(clearHalf), y(seat))
      ..lineTo(x(clearHalf), y(seat) - (y(seat) - coverBottom) * 0.45)
      ..lineTo(x(-clearHalf), y(seat) - (y(seat) - coverBottom) * 0.45)
      ..lineTo(x(-clearHalf), y(seat))
      ..close();
    canvas.drawPath(frame, cadStroke(palette.ink, CadWeight.outline));
    canvas.drawRect(
      Rect.fromLTRB(x(-clearHalf - 1), coverTop, x(clearHalf + 1), coverBottom),
      Paint()..color = palette.ink,
    );

    final label = castingLabel;
    if (label != null) {
      final anchor = Offset(x(flangeHalf) + 16, coverTop - 6);
      final rect = labels.draw(canvas, label.toUpperCase(), anchor, 8.5, color: palette.callout, maxWidth: 104);
      canvas.drawLine(
        Offset(x(clearHalf + 1), (coverTop + coverBottom) / 2),
        Offset(rect.left - 4, rect.center.dy),
        cadStroke(palette.callout, CadWeight.dimension),
      );
    }
  }

  // -------------------------------------------------------------- dimensions

  void _drawHeightChain(
    Canvas canvas,
    LabelPlacer labels,
    _Geometry g,
    Size size,
    double marginLeft,
    _Map x,
    _Map y,
  ) {
    final chainX = math.max(56.0, marginLeft - 44);
    // Far enough in that the right-aligned overall reading clears the border.
    final overallX = math.max(42.0, marginLeft - 96);
    final color = palette.dimension;

    for (final laid in layout.pieces) {
      final top = y(laid.topElevationFt);
      final bottom = y(laid.bottomElevationFt);
      final edge = x(-g.halfOutOf(laid.piece));

      drawExtensionLine(canvas, Offset(edge, top), Offset(chainX + 6, top), palette.thinInk);
      drawExtensionLine(canvas, Offset(edge, bottom), Offset(chainX + 6, bottom), palette.thinInk);
      drawDimensionTick(canvas, Offset(chainX, top), true, color);
      drawDimensionTick(canvas, Offset(chainX, bottom), true, color);
      drawDimensionLine(canvas, Offset(chainX, top), Offset(chainX, bottom), color, head: 4);

      final text = inchesText(laid.piece.heightIn);
      final tall = (bottom - top).abs() > 16;
      labels.draw(
        canvas,
        text,
        Offset(chainX - 6, (top + bottom) / 2 - 5.5),
        tall ? 10 : 8.5,
        align: LabelAnchor.right,
        color: color,
        avoidOverlap: !tall,
      );
    }

    // 8" base floor gets its own link in the chain.
    final floorTop = y(layout.floorTopElevationFt);
    final floorBottom = y(layout.floorBottomElevationFt);
    drawDimensionTick(canvas, Offset(chainX, floorBottom), true, color);
    drawDimensionLine(canvas, Offset(chainX, floorTop), Offset(chainX, floorBottom), color, head: 4);
    labels.draw(
      canvas,
      inchesText(layout.baseFloorThicknessIn),
      Offset(chainX - 6, (floorTop + floorBottom) / 2 - 4.5),
      8.5,
      align: LabelAnchor.right,
      color: color,
    );

    // Design height: top of stack down to the outlet invert.
    final yTop = y(layout.topOfStackElevationFt);
    final yInvert = y(layout.invertElevationFt);
    drawDimensionLine(canvas, Offset(overallX, yTop), Offset(overallX, yInvert), color);
    labels.reserve(LabelPlacer.corridor(Offset(overallX, yTop), Offset(overallX, yInvert), pad: 4));
    labels.draw(
      canvas,
      "${(layout.topOfStackElevationFt - layout.invertElevationFt).toStringAsFixed(2)}'",
      Offset(overallX - 5, (yTop + yInvert) / 2 - 6),
      10,
      align: LabelAnchor.right,
      color: color,
      avoidOverlap: false,
    );

    _datum(canvas, labels, overallX, x(-layout.outsideDiameterIn / 2) - 6, yTop, layout.topOfStackElevationFt, 'TOP');
    _datum(
      canvas,
      labels,
      overallX,
      x(-layout.outsideDiameterIn / 2) - 6,
      y(layout.floorBottomElevationFt),
      layout.floorBottomElevationFt,
      'PREP',
    );
  }

  /// Elevation datum: a thin level line with the elevation stacked above it.
  void _datum(
    Canvas canvas,
    LabelPlacer labels,
    double fromX,
    double toX,
    double yy,
    double elevationFt,
    String tag,
  ) {
    canvas.drawLine(
      Offset(fromX - 8, yy),
      Offset(math.max(toX, fromX + 10), yy),
      cadStroke(palette.thinInk, CadWeight.thin),
    );
    labels.draw(
      canvas,
      "${elevationFt.toStringAsFixed(2)}'\n$tag",
      Offset(fromX - 8, yy - 24),
      9,
      color: palette.callout,
      avoidOverlap: false,
    );
  }

  void _drawWidthDimensions(Canvas canvas, LabelPlacer labels, _Geometry g, _Map x, _Map y) {
    final color = palette.dimension;

    // Top of stack: wall / opening / wall.
    final topPiece = layout.pieces.isEmpty ? null : layout.pieces.last;
    if (topPiece != null) {
      final halfOut = g.topHalfOut(topPiece);
      final halfIn = g.topHalfIn(topPiece, castingClearOpeningIn);
      final yTop = y(topPiece.topElevationFt);
      // Clear of the frame-and-cover symbol sitting on the stack.
      final dimY = y(topPiece.topElevationFt + _castingSymbolHeightIn / 12) - 26;
      for (final v in [-halfOut, -halfIn, halfIn, halfOut]) {
        drawExtensionLine(canvas, Offset(x(v), yTop - 4), Offset(x(v), dimY - 4), palette.thinInk);
      }
      _widthSegment(canvas, labels, x(-halfOut), x(-halfIn), dimY, inchesText(halfOut - halfIn), color);
      _widthSegment(
        canvas,
        labels,
        x(-halfIn),
        x(halfIn),
        dimY,
        _across(halfIn * 2),
        color,
      );
      _widthSegment(canvas, labels, x(halfIn), x(halfOut), dimY, inchesText(halfOut - halfIn), color);
    }

    // Base: wall / inside diameter / wall, then the overall outside diameter.
    final halfOut = layout.outsideDiameterIn / 2;
    final halfIn = layout.structureDiameterIn / 2;
    final yBase = y(layout.floorBottomElevationFt);
    final dimY = yBase + 24;
    for (final v in [-halfOut, -halfIn, halfIn, halfOut]) {
      drawExtensionLine(canvas, Offset(x(v), yBase + 3), Offset(x(v), dimY + 4), palette.thinInk);
    }
    _widthSegment(canvas, labels, x(-halfOut), x(-halfIn), dimY, inchesText(layout.wallThicknessIn), color);
    _widthSegment(
      canvas,
      labels,
      x(-halfIn),
      x(halfIn),
      dimY,
      _across(layout.structureDiameterIn),
      color,
    );
    _widthSegment(canvas, labels, x(halfIn), x(halfOut), dimY, inchesText(layout.wallThicknessIn), color);
    _widthSegment(
      canvas,
      labels,
      x(-halfOut),
      x(halfOut),
      dimY + 16,
      _across(layout.outsideDiameterIn),
      color,
    );
    if (!layout.isRound) {
      // The section only shows the width, so the depth is called out in text.
      labels.draw(
        canvas,
        '${inchesText(layout.size.insideLengthIn)}" DEEP (N-S)',
        Offset(x(0), dimY + 30),
        8.5,
        align: LabelAnchor.center,
        color: color,
      );
    }
  }

  void _widthSegment(
    Canvas canvas,
    LabelPlacer labels,
    double x0,
    double x1,
    double yy,
    String text,
    Color color,
  ) {
    drawDimensionLine(canvas, Offset(x0, yy), Offset(x1, yy), color, head: 4);
    drawDimensionTick(canvas, Offset(x0, yy), false, color, half: 3);
    drawDimensionTick(canvas, Offset(x1, yy), false, color, half: 3);
    labels.draw(
      canvas,
      text,
      Offset((x0 + x1) / 2, yy - 13),
      (x1 - x0).abs() > 34 ? 9.5 : 8,
      align: LabelAnchor.center,
      color: color,
      avoidOverlap: (x1 - x0).abs() <= 34,
    );
  }

  // ----------------------------------------------------------------- callouts

  void _drawPieceCallouts(
    Canvas canvas,
    LabelPlacer labels,
    _Geometry g,
    Size size,
    double marginRight,
    _Map x,
    _Map y,
  ) {
    final marks = layout.pieceMarks;
    final anchorX = size.width - marginRight + 14;
    for (final laid in layout.pieces) {
      final top = y(laid.topElevationFt);
      final bottom = y(laid.bottomElevationFt);
      final mid = (top + bottom) / 2;
      final mark = marks[laid.piece.id] ?? '';
      final rect = labels.draw(
        canvas,
        '$mark  ${laid.piece.description.toUpperCase()}',
        Offset(anchorX, mid - 6),
        8.5,
        color: palette.callout,
        maxWidth: math.max(56, marginRight - 20),
      );
      canvas.drawLine(
        Offset(x(g.halfOutOf(laid.piece)) + 3, mid),
        Offset(rect.left - 5, rect.center.dy),
        cadStroke(palette.callout, CadWeight.dimension),
      );
    }
  }

  // -------------------------------------------------------------------- pipes

  /// Horizontal offset of a penetration projected onto the section plane.
  double _projectedOffsetIn(PipePenetration pipe) =>
      math.sin(pipe.angleRadFromNorthClockwise) *
      layout.size.outsideReachIn(pipe.normalizedAngleDeg);

  bool _breaksWall(PipePenetration pipe) =>
      _projectedOffsetIn(pipe).abs() >= layout.structureDiameterIn / 2 - 0.01;

  void _reservePipeZones(LabelPlacer labels, _Geometry g, _Map x, _Map y) {
    for (final pipe in pipes) {
      final half = pipe.holeSizeIn / 2 / 12;
      final center = layout.buildInvertElevationFt(pipe) + pipe.outsideDiameterIn / 24;
      final offset = _projectedOffsetIn(pipe);
      final left = _breaksWall(pipe)
          ? (offset > 0 ? x(layout.structureDiameterIn / 2) : x(-layout.outsideDiameterIn / 2 - _pipeStubIn))
          : x(offset - pipe.holeSizeIn / 2);
      final right = _breaksWall(pipe)
          ? (offset > 0 ? x(layout.outsideDiameterIn / 2 + _pipeStubIn) : x(-layout.structureDiameterIn / 2))
          : x(offset + pipe.holeSizeIn / 2);
      labels.reserve(
        Rect.fromLTRB(
          math.min(left, right),
          y(center + half),
          math.max(left, right),
          y(center - half),
        ).inflate(4),
      );
    }
  }

  void _drawPipes(
    Canvas canvas,
    LabelPlacer labels,
    Size size,
    double marginLeft,
    double marginRight,
    _Map x,
    _Map y,
  ) {
    for (final pipe in pipes) {
      final conflicted = conflictedPipes.contains(pipe.name);
      final color = conflicted ? palette.conflict : palette.pipe;
      final holeColor = conflicted ? palette.conflict : palette.hole;
      final offset = _projectedOffsetIn(pipe);
      final onRight = offset >= 0;
      // Shop rule: the bottom of the opening never breaks into the floor slab.
      final invertFt = layout.buildInvertElevationFt(pipe);
      final yInvert = y(invertFt);
      final yCrown = y(invertFt + pipe.outsideDiameterIn / 12);
      Offset leaderFrom;

      if (_breaksWall(pipe)) {
        // Cut through the wall: sharp opening plus the pipe stub outside it.
        final sign = onRight ? 1.0 : -1.0;
        final inner = x(sign * layout.structureDiameterIn / 2);
        final outer = x(sign * (layout.outsideDiameterIn / 2 + _pipeStubIn));
        final wallFace = x(sign * layout.outsideDiameterIn / 2);
        final holeHalf = pipe.holeSizeIn / 2 / 12;
        final centerElev = invertFt + pipe.outsideDiameterIn / 24;

        // Cored opening through the wall, dashed like the shop drawings.
        for (final elev in [centerElev - holeHalf, centerElev + holeHalf]) {
          drawDashedLine(
            canvas,
            Offset(inner, y(elev)),
            Offset(wallFace, y(elev)),
            cadStroke(holeColor, CadWeight.hidden),
          );
        }

        final stub = Rect.fromLTRB(
          math.min(wallFace, outer),
          yCrown,
          math.max(wallFace, outer),
          yInvert,
        );
        canvas.drawRect(stub, cadStroke(color, CadWeight.pipe));
        drawCenterLine(
          canvas,
          Offset(inner, stub.center.dy),
          Offset(outer + sign * 6, stub.center.dy),
          cadStroke(color, CadWeight.thin),
        );
        leaderFrom = Offset(onRight ? stub.right : stub.left, stub.center.dy);
        labels.reserve(stub.inflate(5));
      } else {
        // Behind or in front of the section plane: the opening projects as a
        // circle on the barrel, exactly how MH Pro shows skewed penetrations.
        final center = Offset(x(offset), (yCrown + yInvert) / 2);
        final pipeR = (yInvert - yCrown).abs() / 2;
        final holeR = pipeR * (pipe.holeSizeIn / math.max(pipe.outsideDiameterIn, 0.01));
        drawDashedCircle(canvas, center, holeR, cadStroke(holeColor, CadWeight.hidden));
        final angle = pipe.normalizedAngleDeg;
        final behind = angle < 90 || angle > 270;
        if (behind) {
          drawDashedCircle(canvas, center, pipeR, cadStroke(color, CadWeight.hidden));
        } else {
          canvas.drawCircle(center, pipeR, cadStroke(color, CadWeight.pipe));
        }
        leaderFrom = Offset(center.dx + (onRight ? pipeR : -pipeR), center.dy);
      }

      // Invert level line across the barrel.
      drawDashedLine(
        canvas,
        Offset(x(-layout.outsideDiameterIn / 2) - 4, yInvert),
        Offset(x(layout.outsideDiameterIn / 2) + 4, yInvert),
        cadStroke(color, CadWeight.thin),
        dash: 4,
        gap: 3,
      );

      final rect = labels.draw(
        canvas,
        '${pipe.name}  ${inchesText(pipe.outsideDiameterIn)}" OD\n'
        'INV ${invertFt.toStringAsFixed(2)}'
        '${layout.isInvertRaised(pipe) ? ' (SET ON FLOOR)' : ''}  '
        '${pipe.normalizedAngleDeg.toStringAsFixed(0)}\u00B0'
        '${_breaksWall(pipe) ? '' : (pipe.normalizedAngleDeg < 90 || pipe.normalizedAngleDeg > 270 ? '  (FAR SIDE)' : '  (NEAR SIDE)')}',
        Offset(
          onRight
              ? math.max(size.width - marginRight + 14, leaderFrom.dx + 12)
              : math.min(marginLeft - 14, leaderFrom.dx - 12),
          (yCrown + yInvert) / 2 - 12,
        ),
        8.5,
        align: onRight ? LabelAnchor.left : LabelAnchor.right,
        color: color,
        maxWidth: math.max(56, (onRight ? marginRight : marginLeft) - 20),
      );
      drawLeader(
        canvas,
        Offset(onRight ? rect.left - 4 : rect.right + 4, rect.center.dy),
        leaderFrom,
        color,
        head: 4,
      );
    }
  }

  // ------------------------------------------------------------------- sheet

  void _drawFrame(Canvas canvas, Size size, LabelPlacer labels, double scale) {
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
      'SCALE 1:${(96 / scale).round()}',
      Offset(size.width - 9, 7),
      8.5,
      align: LabelAnchor.right,
      color: palette.callout,
    );
    // Title bar and scale-bar strip are off limits to every other annotation.
    labels.topGuard = 26;
    labels.bottomGuard = 22;
  }

  void _drawScaleBar(LabelPlacer labels, Canvas canvas, Size size, double scale) {
    final barLen = 12 * scale; // one foot
    final y0 = size.height - 14;
    const x0 = 12.0;
    final paint = cadStroke(palette.ink, CadWeight.hidden);
    canvas.drawLine(Offset(x0, y0), Offset(x0 + barLen, y0), paint);
    canvas.drawLine(Offset(x0, y0 - 4), Offset(x0, y0 + 4), paint);
    canvas.drawLine(Offset(x0 + barLen, y0 - 4), Offset(x0 + barLen, y0 + 4), paint);
    labels.draw(
      canvas,
      "1'-0\"",
      Offset(x0 + barLen + 6, y0 - 6),
      8,
      color: palette.callout,
      avoidOverlap: false,
      insideGuards: false,
    );
  }

  @override
  bool shouldRepaint(covariant ElevationPainter oldDelegate) => true;
}

typedef _Map = double Function(double);

/// Screen geometry of the stack: half widths, mirroring and the left profile
/// polyline the outline is built from.
class _Geometry {
  _Geometry({required this.layout, required this.x, required this.y, required this.centerX});

  final StructureLayout layout;
  final _Map x;
  final _Map y;
  final double centerX;

  Offset mirror(Offset p) => Offset(2 * centerX - p.dx, p.dy);

  double halfOutOf(PrecastPiece piece) => piece.type == PieceType.gradeRing
      ? piece.insideDiameterIn / 2 + piece.wallThicknessIn
      : piece.outsideDiameterIn / 2;

  double topHalfOut(LaidPiece laid) => laid.piece.type == PieceType.conicalTop
      ? (laid.piece.topOpeningDiameterIn ?? 24) / 2 + laid.piece.wallThicknessIn
      : halfOutOf(laid.piece);

  double topHalfIn(LaidPiece laid, double castingClearOpeningIn) => switch (laid.piece.type) {
    PieceType.conicalTop || PieceType.flatTop =>
      (laid.piece.topOpeningDiameterIn ?? castingClearOpeningIn) / 2,
    _ => laid.piece.insideDiameterIn / 2,
  };

  /// Elevation where a cone starts to taper.
  double shoulderElevationFt(LaidPiece laid) =>
      laid.bottomElevationFt + (laid.topElevationFt - laid.bottomElevationFt) * 0.12;

  /// Left half of the structure silhouette, bottom to top.
  List<Offset> leftProfile() {
    final points = <Offset>[];
    var currentHalf = layout.outsideDiameterIn / 2;
    points.add(Offset(x(-currentHalf), y(layout.floorBottomElevationFt)));
    points.add(Offset(x(-currentHalf), y(layout.floorTopElevationFt)));

    for (final laid in layout.pieces) {
      final piece = laid.piece;
      final halfOut = halfOutOf(piece);
      if ((halfOut - currentHalf).abs() > 0.01) {
        points.add(Offset(x(-currentHalf), y(laid.bottomElevationFt)));
        points.add(Offset(x(-halfOut), y(laid.bottomElevationFt)));
        currentHalf = halfOut;
      }
      if (piece.type == PieceType.conicalTop) {
        final topHalf = topHalfOut(laid);
        points.add(Offset(x(-halfOut), y(shoulderElevationFt(laid))));
        points.add(Offset(x(-topHalf), y(laid.topElevationFt)));
        currentHalf = topHalf;
      } else {
        points.add(Offset(x(-halfOut), y(laid.topElevationFt)));
      }
    }
    return points;
  }
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
