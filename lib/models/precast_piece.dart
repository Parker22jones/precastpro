import 'dart:math' as math;

import 'structure_size.dart';

/// Catalog of standard precast concrete manhole components.
enum PieceType { base, riser, flatTop, conicalTop, gradeRing }

extension PieceTypeLabel on PieceType {
  String get label => switch (this) {
    PieceType.base => 'Base Section',
    PieceType.riser => 'Riser',
    PieceType.flatTop => 'Flat Top',
    PieceType.conicalTop => 'Conical Top',
    PieceType.gradeRing => 'Grade Ring',
  };
}

class PrecastPiece {
  const PrecastPiece({
    required this.id,
    required this.description,
    required this.type,
    required this.insideDiameterIn,
    required this.heightIn,
    required this.weightLbs,
    required this.wallThicknessIn,
    this.topOpeningDiameterIn,
    this.insideLengthIn,
  });

  final String id;
  final String description;
  final PieceType type;

  /// Inside diameter of the barrel, in inches.
  final double insideDiameterIn;

  /// Laying height of the piece, in inches.
  final double heightIn;

  final double weightLbs;
  final double wallThicknessIn;

  /// For tops: diameter of the access opening, in inches.
  final double? topOpeningDiameterIn;

  /// Inside north-south dimension of a box piece; null for round barrels,
  /// whose [insideDiameterIn] describes both directions.
  final double? insideLengthIn;

  bool get isRectangular => insideLengthIn != null;

  /// Inside east-west dimension, which the elevation section shows.
  double get insideWidthIn => insideDiameterIn;

  double get outsideDiameterIn => insideDiameterIn + 2 * wallThicknessIn;
}

/// Standard wall thickness of a parametric box structure, in inches.
const double kBoxWallThicknessIn = 6.0;

/// Unit weight of reinforced concrete, in pounds per cubic foot.
const double kConcreteDensityPcf = 150.0;

/// The pieces available to build one structure size: round sizes come off the
/// standard forms, box sizes are parametric and sized on demand.
class PieceSet {
  const PieceSet({
    required this.base,
    required this.risers,
    required this.flatTop,
    required this.gradeRings,
    this.conicalTop,
  });

  final PrecastPiece base;
  final List<PrecastPiece> risers;
  final PrecastPiece flatTop;
  final List<PrecastPiece> gradeRings;

  /// Box structures have no conical form, so [top] falls back to the slab.
  final PrecastPiece? conicalTop;

  bool get hasConicalTop => conicalTop != null;

  PrecastPiece top({required bool conical}) => conical ? (conicalTop ?? flatTop) : flatTop;
}

/// Standard floor thickness of a precast base section, in inches.
const double kBaseFloorThicknessIn = 8.0;

/// Minimum acceptable clear distance between two pipe penetrations, in inches.
const double kMinPipeClearanceIn = 6.0;

class PieceCatalog {
  const PieceCatalog._();

  static const List<PrecastPiece> pieces = [
    // ----- 48" structures -----
    PrecastPiece(
      id: 'B48',
      description: '48" Base Section (8" floor)',
      type: PieceType.base,
      insideDiameterIn: 48,
      heightIn: 48,
      weightLbs: 4100,
      wallThicknessIn: 5,
    ),
    PrecastPiece(
      id: 'R48-12',
      description: '48" Riser - 12" high',
      type: PieceType.riser,
      insideDiameterIn: 48,
      heightIn: 12,
      weightLbs: 1050,
      wallThicknessIn: 5,
    ),
    PrecastPiece(
      id: 'R48-24',
      description: '48" Riser - 24" high',
      type: PieceType.riser,
      insideDiameterIn: 48,
      heightIn: 24,
      weightLbs: 2100,
      wallThicknessIn: 5,
    ),
    PrecastPiece(
      id: 'R48-36',
      description: '48" Riser - 36" high',
      type: PieceType.riser,
      insideDiameterIn: 48,
      heightIn: 36,
      weightLbs: 3150,
      wallThicknessIn: 5,
    ),
    PrecastPiece(
      id: 'R48-48',
      description: '48" Riser - 48" high',
      type: PieceType.riser,
      insideDiameterIn: 48,
      heightIn: 48,
      weightLbs: 4200,
      wallThicknessIn: 5,
    ),
    PrecastPiece(
      id: 'FT48',
      description: '48" Flat Top Slab',
      type: PieceType.flatTop,
      insideDiameterIn: 48,
      heightIn: 8,
      weightLbs: 1800,
      wallThicknessIn: 8,
      topOpeningDiameterIn: 24,
    ),
    PrecastPiece(
      id: 'CT48',
      description: '48" Conical (Eccentric) Top',
      type: PieceType.conicalTop,
      insideDiameterIn: 48,
      heightIn: 36,
      weightLbs: 2700,
      wallThicknessIn: 5,
      topOpeningDiameterIn: 24,
    ),

    // ----- 60" structures -----
    PrecastPiece(
      id: 'B60',
      description: '60" Base Section (8" floor)',
      type: PieceType.base,
      insideDiameterIn: 60,
      heightIn: 48,
      weightLbs: 5900,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'R60-12',
      description: '60" Riser - 12" high',
      type: PieceType.riser,
      insideDiameterIn: 60,
      heightIn: 12,
      weightLbs: 1450,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'R60-24',
      description: '60" Riser - 24" high',
      type: PieceType.riser,
      insideDiameterIn: 60,
      heightIn: 24,
      weightLbs: 2900,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'R60-36',
      description: '60" Riser - 36" high',
      type: PieceType.riser,
      insideDiameterIn: 60,
      heightIn: 36,
      weightLbs: 4350,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'R60-48',
      description: '60" Riser - 48" high',
      type: PieceType.riser,
      insideDiameterIn: 60,
      heightIn: 48,
      weightLbs: 5800,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'FT60',
      description: '60" Flat Top Slab',
      type: PieceType.flatTop,
      insideDiameterIn: 60,
      heightIn: 8,
      weightLbs: 2600,
      wallThicknessIn: 8,
      topOpeningDiameterIn: 24,
    ),
    PrecastPiece(
      id: 'CT60',
      description: '60" Conical (Eccentric) Top',
      type: PieceType.conicalTop,
      insideDiameterIn: 60,
      heightIn: 48,
      weightLbs: 4300,
      wallThicknessIn: 6,
      topOpeningDiameterIn: 24,
    ),

    // ----- Grade rings (common to all structure sizes) -----
    PrecastPiece(
      id: 'GR-2',
      description: 'Grade Ring - 2" high',
      type: PieceType.gradeRing,
      insideDiameterIn: 24,
      heightIn: 2,
      weightLbs: 85,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'GR-4',
      description: 'Grade Ring - 4" high',
      type: PieceType.gradeRing,
      insideDiameterIn: 24,
      heightIn: 4,
      weightLbs: 160,
      wallThicknessIn: 6,
    ),
    PrecastPiece(
      id: 'GR-6',
      description: 'Grade Ring - 6" high',
      type: PieceType.gradeRing,
      insideDiameterIn: 24,
      heightIn: 6,
      weightLbs: 240,
      wallThicknessIn: 6,
    ),
  ];

  static PrecastPiece byId(String id) => pieces.firstWhere(
    (p) => p.id == id,
    orElse: () => throw ArgumentError('Unknown piece id: $id'),
  );

  static List<double> get availableDiameters => const [48, 60];

  static List<PrecastPiece> ofType(PieceType type, {double? diameterIn}) => pieces
      .where((p) => p.type == type && (diameterIn == null || p.insideDiameterIn == diameterIn))
      .toList(growable: false);

  static PrecastPiece base(double diameterIn) =>
      ofType(PieceType.base, diameterIn: diameterIn).single;

  static List<PrecastPiece> risers(double diameterIn) =>
      ofType(PieceType.riser, diameterIn: diameterIn);

  static List<PrecastPiece> gradeRings() => ofType(PieceType.gradeRing);

  static PrecastPiece top(double diameterIn, {required bool conical}) =>
      ofType(conical ? PieceType.conicalTop : PieceType.flatTop, diameterIn: diameterIn).single;

  /// Pieces available for [size]: the stock round forms, or parametric box
  /// pieces sized from the interior dimensions on the plans.
  ///
  /// [sumpDepthIn] deepens the base section: the shop casts the sump into the
  /// base rather than adding a piece, so the section gets taller and heavier.
  static PieceSet forSize(
    StructureSize size, {
    double sumpDepthIn = 0,
    double floorThicknessIn = kBaseFloorThicknessIn,
  }) {
    if (size.isRound) {
      final diameterIn = size.insideDiameterIn;
      return PieceSet(
        base: _withSump(base(diameterIn), sumpDepthIn),
        risers: risers(diameterIn),
        flatTop: top(diameterIn, conical: false),
        conicalTop: top(diameterIn, conical: true),
        gradeRings: gradeRings(),
      );
    }
    return PieceSet(
      base: _boxBase(size, sumpDepthIn: sumpDepthIn, floorThicknessIn: floorThicknessIn),
      risers: [for (final h in const [12.0, 24.0, 36.0, 48.0]) _boxRiser(size, h)],
      flatTop: _boxTop(size),
      gradeRings: gradeRings(),
    );
  }

  /// Base section for [size], including any sump cast into it.
  static PrecastPiece baseFor(
    StructureSize size, {
    double sumpDepthIn = 0,
    double floorThicknessIn = kBaseFloorThicknessIn,
  }) => forSize(size, sumpDepthIn: sumpDepthIn, floorThicknessIn: floorThicknessIn).base;

  /// Deepens a stock round base by [sumpDepthIn], adding the extra ring of
  /// barrel concrete the deeper section carries.
  static PrecastPiece _withSump(PrecastPiece base, double sumpDepthIn) {
    if (sumpDepthIn <= 0.01) return base;
    final od = base.outsideDiameterIn;
    final id = base.insideDiameterIn;
    final ringAreaSqIn = math.pi * (od * od - id * id) / 4.0;
    final addedLbs = (ringAreaSqIn * sumpDepthIn / 1728.0) * kConcreteDensityPcf;
    return PrecastPiece(
      id: '${base.id}-S${sumpDepthIn.round()}',
      description:
          '${base.description.replaceAll(')', '')}, ${sumpDepthIn.round()}" sump)',
      type: PieceType.base,
      insideDiameterIn: base.insideDiameterIn,
      insideLengthIn: base.insideLengthIn,
      heightIn: base.heightIn + sumpDepthIn,
      weightLbs: base.weightLbs + addedLbs,
      wallThicknessIn: base.wallThicknessIn,
    );
  }

  /// Weight of a box shell [heightIn] tall, plus an optional slab.
  static double _boxWeightLbs(StructureSize size, double heightIn, {double slabThicknessIn = 0}) {
    final shellArea = size.outsideWidthIn * size.outsideLengthIn - size.insideWidthIn * size.insideLengthIn;
    final slabArea = size.outsideWidthIn * size.outsideLengthIn;
    final volumeCuIn = shellArea * (heightIn - slabThicknessIn) + slabArea * slabThicknessIn;
    return (volumeCuIn / 1728.0) * kConcreteDensityPcf;
  }

  static String _boxTag(StructureSize size) =>
      '${size.insideWidthIn.round()}x${size.insideLengthIn.round()}';

  static String _boxSizeText(StructureSize size) =>
      '${size.insideWidthIn.round()}" x ${size.insideLengthIn.round()}"';

  static PrecastPiece _boxBase(
    StructureSize size, {
    double sumpDepthIn = 0,
    double floorThicknessIn = kBaseFloorThicknessIn,
  }) {
    final sump = math.max(sumpDepthIn, 0.0);
    final heightIn = 48 + sump;
    final deep = sump > 0.01;
    return PrecastPiece(
      id: 'BOX-B-${_boxTag(size)}${deep ? '-S${sump.round()}' : ''}',
      description:
          '${_boxSizeText(size)} Box Base Section (${floorThicknessIn.round()}" floor'
          '${deep ? ', ${sump.round()}" sump' : ''})',
      type: PieceType.base,
      insideDiameterIn: size.insideWidthIn,
      insideLengthIn: size.insideLengthIn,
      heightIn: heightIn,
      weightLbs: _boxWeightLbs(size, heightIn, slabThicknessIn: floorThicknessIn),
      wallThicknessIn: size.wallThicknessIn,
    );
  }

  static PrecastPiece _boxRiser(StructureSize size, double heightIn) => PrecastPiece(
    id: 'BOX-R-${_boxTag(size)}-${heightIn.round()}',
    description: '${_boxSizeText(size)} Box Riser - ${heightIn.round()}" high',
    type: PieceType.riser,
    insideDiameterIn: size.insideWidthIn,
    insideLengthIn: size.insideLengthIn,
    heightIn: heightIn,
    weightLbs: _boxWeightLbs(size, heightIn),
    wallThicknessIn: size.wallThicknessIn,
  );

  static PrecastPiece _boxTop(StructureSize size) {
    const thicknessIn = 8.0;
    final opening = math.min(24.0, math.min(size.insideWidthIn, size.insideLengthIn));
    final slabVolume =
        (size.outsideWidthIn * size.outsideLengthIn - math.pi * opening * opening / 4) * thicknessIn;
    return PrecastPiece(
      id: 'BOX-T-${_boxTag(size)}',
      description: '${_boxSizeText(size)} Box Top Slab',
      type: PieceType.flatTop,
      insideDiameterIn: size.insideWidthIn,
      insideLengthIn: size.insideLengthIn,
      heightIn: thicknessIn,
      weightLbs: (slabVolume / 1728.0) * kConcreteDensityPcf,
      wallThicknessIn: size.wallThicknessIn,
      topOpeningDiameterIn: opening,
    );
  }
}
