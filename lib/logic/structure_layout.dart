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
/// Reference datum: the 8" base floor is placed with its bottom at the
/// structure invert elevation, so the first stacked piece starts at
/// invert + 8", and the stack (whose heights total the structural depth)
/// finishes exactly at the rim elevation.
class StructureLayout {
  StructureLayout({
    required this.stack,
    required this.rimElevationFt,
    required this.invertElevationFt,
    required this.structureDiameterIn,
  }) : pieces = _lay(stack, invertElevationFt);

  final StackResult stack;
  final double rimElevationFt;
  final double invertElevationFt;
  final double structureDiameterIn;
  final List<LaidPiece> pieces;

  double get floorBottomElevationFt => invertElevationFt;
  double get floorTopElevationFt => invertElevationFt + kBaseFloorThicknessIn / 12.0;
  double get topOfStackElevationFt =>
      pieces.isEmpty ? floorTopElevationFt : pieces.last.topElevationFt;

  double get wallThicknessIn => PieceCatalog.base(structureDiameterIn).wallThicknessIn;
  double get outsideDiameterIn => structureDiameterIn + 2 * wallThicknessIn;

  /// Elevations of every horizontal joint in the stack.
  List<double> get jointElevationsFt =>
      [for (var i = 0; i < pieces.length - 1; i++) pieces[i].topElevationFt];

  static List<LaidPiece> _lay(StackResult stack, double invertElevationFt) {
    final out = <LaidPiece>[];
    var elevation = invertElevationFt + kBaseFloorThicknessIn / 12.0;
    for (final item in stack.items) {
      for (var i = 0; i < item.count; i++) {
        out.add(LaidPiece(piece: item.piece, bottomElevationFt: elevation));
        elevation += item.piece.heightIn / 12.0;
      }
    }
    return out;
  }
}
