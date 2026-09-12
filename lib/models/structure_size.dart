import 'dart:math' as math;

/// Plan shape of a structure. Round barrels come off standard forms; boxes are
/// parametric, sized by the interior width and length the plans call for.
enum StructureShape { round, rectangular }

extension StructureShapeLabel on StructureShape {
  String get label => switch (this) {
    StructureShape.round => 'Round',
    StructureShape.rectangular => 'Rectangular',
  };
}

/// The flat face of a box a penetration passes through.
enum BoxWall { north, east, south, west }

extension BoxWallLabel on BoxWall {
  String get label => switch (this) {
    BoxWall.north => 'N WALL',
    BoxWall.east => 'E WALL',
    BoxWall.south => 'S WALL',
    BoxWall.west => 'W WALL',
  };

  /// True for the two faces the elevation section is taken through.
  bool get isEastWest => this == BoxWall.east || this == BoxWall.west;
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

  factory StructureSize.round(double insideDiameterIn, {double? wallThicknessIn}) => StructureSize(
    shape: StructureShape.round,
    insideWidthIn: insideDiameterIn,
    insideLengthIn: insideDiameterIn,
    wallThicknessIn:
        wallThicknessIn ??
        standardWallThicknessIn(
          shape: StructureShape.round,
          insideWidthIn: insideDiameterIn,
          insideLengthIn: insideDiameterIn,
        ),
  );

  factory StructureSize.rectangular({
    required double insideWidthIn,
    required double insideLengthIn,
    double? wallThicknessIn,
  }) {
    final width = math.max(insideWidthIn, 12.0);
    final length = math.max(insideLengthIn, 12.0);
    return StructureSize(
      shape: StructureShape.rectangular,
      insideWidthIn: width,
      insideLengthIn: length,
      wallThicknessIn:
          wallThicknessIn ??
          standardWallThicknessIn(
            shape: StructureShape.rectangular,
            insideWidthIn: width,
            insideLengthIn: length,
          ),
    );
  }

  /// Wall the shop casts for a given interior, before any manual override.
  ///
  /// Round barrels follow ASTM C478 (one twelfth of the inside diameter, which
  /// the standard forms round up: 48" -> 5", 60" -> 6", 72" -> 7"); box
  /// sections follow ASTM C913, 6" walls up to a 60" clear span and 8" above.
  static double standardWallThicknessIn({
    required StructureShape shape,
    required double insideWidthIn,
    required double insideLengthIn,
  }) {
    if (shape == StructureShape.round) {
      return math.max(5.0, insideWidthIn / 12.0 + 1.0);
    }
    return math.max(insideWidthIn, insideLengthIn) > 60 ? 8.0 : 6.0;
  }

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

  /// Face a penetration on [angleDegFromNorth] passes through; null for a
  /// round barrel, which has no flat faces.
  BoxWall? wallFaceFor(double angleDegFromNorth) {
    if (isRound) return null;
    final rad = angleDegFromNorth * math.pi / 180.0;
    final east = math.sin(rad);
    final north = math.cos(rad);
    final byEast = east.abs() < 1e-9
        ? double.infinity
        : (insideWidthIn / 2) / east.abs();
    final byNorth = north.abs() < 1e-9
        ? double.infinity
        : (insideLengthIn / 2) / north.abs();
    if (byEast <= byNorth) return east >= 0 ? BoxWall.east : BoxWall.west;
    return north >= 0 ? BoxWall.north : BoxWall.south;
  }

  /// Angle between the pipe and the wall it passes through, measured off the
  /// perpendicular: 0 degrees is a square entry. Always 0 on a round barrel,
  /// where the pipe runs radially into the wall.
  double skewDegFor(double angleDegFromNorth) {
    final face = wallFaceFor(angleDegFromNorth);
    if (face == null) return 0;
    final rad = angleDegFromNorth * math.pi / 180.0;
    final normal = face.isEastWest ? math.sin(rad).abs() : math.cos(rad).abs();
    return math.acos(normal.clamp(0.0, 1.0)) * 180.0 / math.pi;
  }

  /// Width the shop has to cut in the wall face for an opening of
  /// [openingDiameterIn] entering on [angleDegFromNorth]. A skewed pipe cuts
  /// an ellipse, so the face opening stretches by 1/cos(skew).
  double wallCutWidthIn(double openingDiameterIn, double angleDegFromNorth) {
    final skewRad = skewDegFor(angleDegFromNorth) * math.pi / 180.0;
    final cos = math.cos(skewRad);
    // Beyond a 75 degree skew the cut runs away; the validator flags it.
    return openingDiameterIn / math.max(cos, 0.2588);
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
