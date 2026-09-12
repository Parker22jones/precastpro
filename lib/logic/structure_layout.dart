import 'dart:math' as math;

import '../logic/stack_calculator.dart';
import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';
import '../models/structure_size.dart';

/// A single stacked piece placed at its real world elevation.
class LaidPiece {
  const LaidPiece({required this.piece, required this.bottomElevationFt});

  final PrecastPiece piece;
  final double bottomElevationFt;

  double get topElevationFt => bottomElevationFt + piece.heightIn / 12.0;
}

/// Turns a [StackResult] into concrete elevations so the painters and the PDF
/// all draw the same geometry.
///
/// Reference datum: the base floor is placed with its bottom at the sump
/// floor (invert minus the sump depth), so the first stacked piece starts one
/// floor thickness above it, and the stack (whose heights total the structural
/// depth) finishes exactly at the rim elevation.
class StructureLayout {
  StructureLayout({
    required this.stack,
    required this.rimElevationFt,
    required this.invertElevationFt,
    required this.size,
    this.sumpDepthIn = 0,
    this.baseFloorThicknessIn = kBaseFloorThicknessIn,
  }) : pieces = _lay(stack, invertElevationFt - sumpDepthIn / 12.0, baseFloorThicknessIn);

  final StackResult stack;
  final double rimElevationFt;
  final double invertElevationFt;

  /// Plan geometry of the structure: round diameter or box width x length.
  final StructureSize size;

  /// Sump carried below the outlet invert, in inches.
  final double sumpDepthIn;

  /// Floor slab cast into the base section, in inches.
  final double baseFloorThicknessIn;

  final List<LaidPiece> pieces;

  double get sumpFloorElevationFt => invertElevationFt - sumpDepthIn / 12.0;
  double get floorBottomElevationFt => sumpFloorElevationFt;
  double get floorTopElevationFt => sumpFloorElevationFt + baseFloorThicknessIn / 12.0;
  double get topOfStackElevationFt =>
      pieces.isEmpty ? floorTopElevationFt : pieces.last.topElevationFt;

  double get structureDiameterIn => size.insideWidthIn;
  double get wallThicknessIn => size.wallThicknessIn;
  double get outsideDiameterIn => size.outsideWidthIn;
  bool get isRound => size.isRound;

  /// Invert a penetration is actually built at.
  ///
  /// Shop rule: no opening may break into the floor slab, so an invert entered
  /// below the top of the base floor is raised flush with that slab.
  double buildInvertElevationFt(PipePenetration pipe) =>
      math.max(pipe.invertElevationFt, floorTopElevationFt);

  /// True when [pipe] was entered below the top of the floor slab and had to
  /// be lifted to sit on it.
  bool isInvertRaised(PipePenetration pipe) =>
      pipe.invertElevationFt < floorTopElevationFt - 0.001;

  /// Sheet marks keyed by catalog piece id, lettered top down the way the
  /// shop submittals key the elevation to the bill of materials.
  Map<String, String> get pieceMarks {
    final marks = <String, String>{};
    for (final laid in pieces.reversed) {
      marks.putIfAbsent(laid.piece.id, () => String.fromCharCode(65 + marks.length));
    }
    return marks;
  }

  /// Elevations of every horizontal joint in the stack.
  List<double> get jointElevationsFt => [
    for (var i = 0; i < pieces.length - 1; i++) pieces[i].topElevationFt,
  ];

  static List<LaidPiece> _lay(
    StackResult stack,
    double floorBottomElevationFt,
    double baseFloorThicknessIn,
  ) {
    final out = <LaidPiece>[];
    var elevation = floorBottomElevationFt + baseFloorThicknessIn / 12.0;
    for (final item in stack.items) {
      for (var i = 0; i < item.count; i++) {
        out.add(LaidPiece(piece: item.piece, bottomElevationFt: elevation));
        elevation += item.piece.heightIn / 12.0;
      }
    }
    return out;
  }
}
