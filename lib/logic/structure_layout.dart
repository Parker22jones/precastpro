import '../logic/stack_calculator.dart';
import '../models/precast_piece.dart';

/// A single stacked piece placed at its real world elevation.
class LaidPiece {
  const LaidPiece({
    required this.piece,
    required this.bottomElevationFt,
  });

  final PrecastPiece piece;
  final double bottomElevationFt;

  double get topElevationFt => bottomElevationFt + piece.heightIn / 12.0;
}

/// Turns a [StackResult] into concrete elevations so the painters and the PDF
/// all draw the same geometry.
///
/// Reference datum: the 8" base floor is placed with its bottom at the sump
/// floor (invert minus the sump depth), so the first stacked piece starts 8"
/// above it, and the stack (whose heights total the structural depth)
/// finishes exactly at the rim elevation.
class StructureLayout {
  StructureLayout({
    required this.stack,
    required this.rimElevationFt,
    required this.invertElevationFt,
    required this.structureDiameterIn,
    this.sumpDepthIn = 0,
  }) : pieces = _lay(stack, invertElevationFt - sumpDepthIn / 12.0);

  final StackResult stack;
  final double rimElevationFt;
  final double invertElevationFt;
  final double structureDiameterIn;

  /// Sump carried below the outlet invert, in inches.
  final double sumpDepthIn;

  final List<LaidPiece> pieces;

  double get sumpFloorElevationFt => invertElevationFt - sumpDepthIn / 12.0;
  double get floorBottomElevationFt => sumpFloorElevationFt;
  double get floorTopElevationFt => sumpFloorElevationFt + kBaseFloorThicknessIn / 12.0;
  double get topOfStackElevationFt =>
      pieces.isEmpty ? floorTopElevationFt : pieces.last.topElevationFt;

  double get wallThicknessIn => PieceCatalog.base(structureDiameterIn).wallThicknessIn;
  double get outsideDiameterIn => structureDiameterIn + 2 * wallThicknessIn;

  /// Elevations of every horizontal joint in the stack.
  List<double> get jointElevationsFt =>
      [for (var i = 0; i < pieces.length - 1; i++) pieces[i].topElevationFt];

  static List<LaidPiece> _lay(StackResult stack, double floorBottomElevationFt) {
    final out = <LaidPiece>[];
    var elevation = floorBottomElevationFt + kBaseFloorThicknessIn / 12.0;
    for (final item in stack.items) {
      for (var i = 0; i < item.count; i++) {
        out.add(LaidPiece(piece: item.piece, bottomElevationFt: elevation));
        elevation += item.piece.heightIn / 12.0;
      }
    }
    return out;
  }
}
