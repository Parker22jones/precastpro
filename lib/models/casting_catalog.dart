/// East Jordan Iron Works (EJ) castings stocked for manhole and inlet tops.
class EjCasting {
  const EjCasting({
    required this.id,
    required this.description,
    required this.sku,
    required this.weightLbs,
    required this.clearOpeningIn,
  });

  final String id;
  final String description;
  final String sku;
  final double weightLbs;

  /// Clear opening the top slab or cone has to be cast for.
  final double clearOpeningIn;

  String get label => '$id - $description';
}

/// Native EJ selection catalog offered in Phase 4.
const List<EjCasting> kEjCastings = [
  EjCasting(
    id: 'EJ 1860',
    description: 'Regular Frame & Grate',
    sku: 'EJ-1860',
    weightLbs: 315,
    clearOpeningIn: 24,
  ),
  EjCasting(
    id: 'EJ 5140-1',
    description: 'Frame',
    sku: 'EJ-5140-1',
    weightLbs: 265,
    clearOpeningIn: 24,
  ),
  EjCasting(
    id: 'EJ 1337Z/1338A',
    description: 'Storm Regular Frame & Grate',
    sku: 'EJ-1337Z',
    weightLbs: 420,
    clearOpeningIn: 27,
  ),
  EjCasting(
    id: 'EJ BJWSA',
    description: 'Manhole Cover',
    sku: 'EJ-BJWSA',
    weightLbs: 135,
    clearOpeningIn: 24,
  ),
];

EjCasting castingById(String id) =>
    kEjCastings.firstWhere((c) => c.id == id, orElse: () => kEjCastings.first);
