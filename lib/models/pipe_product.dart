import 'job_spec.dart';

/// A pipe product offered by the Phase 3 quick-selector. Outside diameters are
/// catalog approximations keyed off the nominal size so the schedule, hole
/// sizes and drawings update from one pick.
class PipeProduct {
  const PipeProduct({
    required this.id,
    required this.label,
    required this.material,
    required this.odFactor,
    required this.odOffsetIn,
    this.round = true,
  });

  final String id;
  final String label;
  final PipeMaterial material;
  final double odFactor;
  final double odOffsetIn;

  /// Slot boxes are rectangular openings rather than round pipe.
  final bool round;

  double outsideDiameterFor(double nominalIn) => nominalIn * odFactor + odOffsetIn;
}

const List<PipeProduct> kPipeProducts = [
  PipeProduct(
    id: 'RCP-B',
    label: 'RCP Wall B',
    material: PipeMaterial.rcp,
    odFactor: 1.0,
    odOffsetIn: 4.0,
  ),
  PipeProduct(
    id: 'PVC-SDR26',
    label: 'PVC SDR 26',
    material: PipeMaterial.pvc,
    odFactor: 1.0,
    odOffsetIn: 0.75,
  ),
  PipeProduct(
    id: 'ADS-N12',
    label: 'ADS N-12 Corrugated',
    material: PipeMaterial.hdpe,
    odFactor: 1.19,
    odOffsetIn: 0.2,
  ),
  PipeProduct(
    id: 'ADS-HP',
    label: 'ADS SaniTite HP',
    material: PipeMaterial.hdpe,
    odFactor: 1.18,
    odOffsetIn: 0.15,
  ),
  PipeProduct(
    id: 'ADS-PP',
    label: 'ADS PP',
    material: PipeMaterial.hdpe,
    odFactor: 1.16,
    odOffsetIn: 0.15,
  ),
  PipeProduct(
    id: 'SLOT-BOX',
    label: 'Slot Box',
    material: PipeMaterial.cmp,
    odFactor: 1.0,
    odOffsetIn: 2.0,
    round: false,
  ),
];

PipeProduct? productById(String? id) {
  if (id == null) return null;
  for (final p in kPipeProducts) {
    if (p.id == id) return p;
  }
  return null;
}

/// Press-Seal connector lookup. Selecting a drive swaps the structural mortar
/// assumption for a cast-in rubber sleeve.
enum PsxConnector { none, directDrive, nyloDrive }

extension PsxConnectorInfo on PsxConnector {
  String get label => switch (this) {
    PsxConnector.none => 'None (mortar)',
    PsxConnector.directDrive => 'PSX: Direct Drive',
    PsxConnector.nyloDrive => 'PSX: Nylo Drive',
  };

  bool get isSleeve => this != PsxConnector.none;

  /// Stock SKU consumed per penetration.
  String? get sku => switch (this) {
    PsxConnector.none => null,
    PsxConnector.directDrive => 'PSX-DD',
    PsxConnector.nyloDrive => 'PSX-ND',
  };

  /// Cast hole allowance over the pipe OD.
  double get holeAllowanceIn => switch (this) {
    PsxConnector.none => 4.0,
    PsxConnector.directDrive => 4.5,
    PsxConnector.nyloDrive => 5.5,
  };

  /// Sleeve wall thickness written on the schedule, in inches.
  double get sleeveThicknessIn => switch (this) {
    PsxConnector.none => 0,
    PsxConnector.directDrive => 0.75,
    PsxConnector.nyloDrive => 1.0,
  };
}
