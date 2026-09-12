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

  double get outsideDiameterIn => insideDiameterIn + 2 * wallThicknessIn;
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
}
