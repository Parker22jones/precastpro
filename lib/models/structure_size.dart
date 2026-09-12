import 'dart:math' as math;

import 'precast_piece.dart';

/// Plan shape of a structure. Round barrels come off standard forms; boxes are
/// parametric, sized by the interior width and length the plans call for.
enum StructureShape { round, rectangular }

extension StructureShapeLabel on StructureShape {
  String get label => switch (this) {
    StructureShape.round => 'Round',
    StructureShape.rectangular => 'Rectangular',
  };
}

/// Plan geometry of a structure: the shape plus the interior dimensions and
/// wall thickness every other engine measures from.
///
/// Width runs east-west (the face drawn in elevation), length runs
/// north-south, and both equal the inside diameter for a round structure.
class StructureSize {
  const StructureSize({
    required this.shape,
    required this.insideWidthIn,
    required this.insideLengthIn,
    required this.wallThicknessIn,
  });

  factory StructureSize.round(double insideDiameterIn) => StructureSize(
    shape: StructureShape.round,
    insideWidthIn: insideDiameterIn,
    insideLengthIn: insideDiameterIn,
    wallThicknessIn: PieceCatalog.base(insideDiameterIn).wallThicknessIn,
  );

  factory StructureSize.rectangular({
    required double insideWidthIn,
    required double insideLengthIn,
    double wallThicknessIn = kBoxWallThicknessIn,
  }) => StructureSize(
    shape: StructureShape.rectangular,
    insideWidthIn: math.max(insideWidthIn, 12),
    insideLengthIn: math.max(insideLengthIn, 12),
    wallThicknessIn: wallThicknessIn,
  );

  final StructureShape shape;
  final double insideWidthIn;
  final double insideLengthIn;
  final double wallThicknessIn;

  bool get isRound => shape == StructureShape.round;

  /// Inside diameter of a round structure; the width of a box.
  double get insideDiameterIn => insideWidthIn;

  double get outsideWidthIn => insideWidthIn + 2 * wallThicknessIn;
  double get outsideLengthIn => insideLengthIn + 2 * wallThicknessIn;

  /// Outside dimension across the elevation section plane.
  double get outsideDiameterIn => outsideWidthIn;

  /// Distance from the centre to the inside wall face along [angleDegFromNorth]
  /// (clockwise). Constant for a round barrel; a ray-box hit for a box.
  double insideReachIn(double angleDegFromNorth) =>
      _reach(insideWidthIn / 2, insideLengthIn / 2, angleDegFromNorth);

  /// Distance from the centre to the outside wall face along the heading.
  double outsideReachIn(double angleDegFromNorth) =>
      _reach(outsideWidthIn / 2, outsideLengthIn / 2, angleDegFromNorth);

  double _reach(double halfEast, double halfNorth, double angleDegFromNorth) {
    if (isRound) return halfEast;
    final rad = angleDegFromNorth * math.pi / 180.0;
    final east = math.sin(rad).abs();
    final north = math.cos(rad).abs();
    final byEast = east < 1e-9 ? double.infinity : halfEast / east;
    final byNorth = north < 1e-9 ? double.infinity : halfNorth / north;
    return math.min(byEast, byNorth);
  }

  /// Centre of a penetration on the mid-wall surface, in inches east/north of
  /// the structure centre.
  ({double eastIn, double northIn}) wallPoint(double angleDegFromNorth) {
    final reach = (insideReachIn(angleDegFromNorth) + outsideReachIn(angleDegFromNorth)) / 2;
    final rad = angleDegFromNorth * math.pi / 180.0;
    return (eastIn: reach * math.sin(rad), northIn: reach * math.cos(rad));
  }

  /// Distance from the centre to the furthest point of the outside face.
  double get outsideHalfDiagonalIn => isRound
      ? outsideWidthIn / 2
      : math.sqrt(
          math.pow(outsideWidthIn / 2, 2) + math.pow(outsideLengthIn / 2, 2),
        );

  /// Largest opening the walls can take, in inches.
  double get maxOpeningIn => math.min(insideWidthIn, insideLengthIn) * 0.75;

  String get sizeLabel => isRound
      ? '${_dim(insideDiameterIn)}" I.D.'
      : '${_dim(insideWidthIn)}" x ${_dim(insideLengthIn)}" I.D.';

  String get label => '$sizeLabel x ${_dim(wallThicknessIn)}" WALL';

  static String _dim(double inches) => inches == inches.roundToDouble()
      ? inches.toStringAsFixed(0)
      : inches.toStringAsFixed(1);

  StructureSize copyWith({
    StructureShape? shape,
    double? insideWidthIn,
    double? insideLengthIn,
    double? wallThicknessIn,
  }) => StructureSize(
    shape: shape ?? this.shape,
    insideWidthIn: insideWidthIn ?? this.insideWidthIn,
    insideLengthIn: insideLengthIn ?? this.insideLengthIn,
    wallThicknessIn: wallThicknessIn ?? this.wallThicknessIn,
  );

  @override
  bool operator ==(Object other) =>
      other is StructureSize &&
      other.shape == shape &&
      other.insideWidthIn == insideWidthIn &&
      other.insideLengthIn == insideLengthIn &&
      other.wallThicknessIn == wallThicknessIn;

  @override
  int get hashCode => Object.hash(shape, insideWidthIn, insideLengthIn, wallThicknessIn);
}
