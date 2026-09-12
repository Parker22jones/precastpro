import 'dart:math' as math;

import 'job_spec.dart';
import 'pipe_product.dart';

/// A single pipe entering or leaving the structure.
class PipePenetration {
  PipePenetration({
    required this.name,
    required this.outsideDiameterIn,
    required this.invertElevationFt,
    required this.horizontalAngleDeg,
    this.material = PipeMaterial.pvc,
    this.boot = BootType.aLok,
    this.productId,
    this.psx = PsxConnector.none,
    this.nominalSizeIn,
    double? holeSizeIn,
  }) : holeSizeIn = holeSizeIn ?? outsideDiameterIn + psx.holeAllowanceIn;

  String name;

  /// Catalog product backing this penetration, when picked from the
  /// quick-selector.
  String? productId;

  /// Nominal size the product was selected at, in inches.
  double? nominalSizeIn;

  /// Press-Seal connector lookup; a sleeve replaces the mortar assumption.
  PsxConnector psx;

  /// Pipe material called out on the schedule.
  PipeMaterial material;

  /// Connector cast into the wall for this penetration.
  BootType boot;

  /// Cored / cast hole diameter, in inches.
  double holeSizeIn;

  /// Outside diameter of the pipe, in inches.
  double outsideDiameterIn;

  /// Invert (bottom inside) elevation of the pipe, in feet.
  double invertElevationFt;

  /// Clockwise horizontal angle in degrees, 0 = North (12 o'clock).
  double horizontalAngleDeg;

  /// Centerline elevation of the pipe, in feet.
  double get centerlineElevationFt => invertElevationFt + (outsideDiameterIn / 2) / 12.0;

  /// Angle normalized into [0, 360).
  double get normalizedAngleDeg {
    final a = horizontalAngleDeg % 360;
    return a < 0 ? a + 360 : a;
  }

  double get angleRadFromNorthClockwise => normalizedAngleDeg * math.pi / 180.0;

  /// Clock-face notation of the horizontal angle (e.g. "3:00").
  String get clockPosition {
    final totalMinutes = (normalizedAngleDeg / 360.0 * 720).round() % 720;
    var hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    if (hour == 0) hour = 12;
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }

  PipeProduct? get product => productById(productId);

  /// Applies a catalog product at [nominalIn], recomputing OD and hole size.
  void applyProduct(PipeProduct selected, double nominalIn) {
    productId = selected.id;
    nominalSizeIn = nominalIn;
    material = selected.material;
    outsideDiameterIn = selected.outsideDiameterFor(nominalIn);
    holeSizeIn = outsideDiameterIn + psx.holeAllowanceIn;
  }

  /// Switches the connector lookup and re-derives the cast hole size.
  void applyPsx(PsxConnector connector) {
    psx = connector;
    if (connector.isSleeve) boot = BootType.pressSeal;
    holeSizeIn = outsideDiameterIn + connector.holeAllowanceIn;
  }

  /// Annular space treatment written on the schedule: mortar by default, or
  /// the rubber sleeve specification once a PSX connector is selected.
  String get sealSpec => psx.isSleeve
      ? '${psx.label} sleeve ${psx.sleeveThicknessIn.toStringAsFixed(2)}" wall - no mortar'
      : 'Mortar annular space ${((holeSizeIn - outsideDiameterIn) / 2).toStringAsFixed(2)}"';

  /// Hole centre coordinates on the structure wall, in inches east/north of
  /// the structure centre, for the given wall radius.
  ({double eastIn, double northIn}) holeCoordinates(double radiusIn) => (
    eastIn: radiusIn * math.sin(angleRadFromNorthClockwise),
    northIn: radiusIn * math.cos(angleRadFromNorthClockwise),
  );

  PipePenetration copy() => PipePenetration(
    name: name,
    outsideDiameterIn: outsideDiameterIn,
    invertElevationFt: invertElevationFt,
    horizontalAngleDeg: horizontalAngleDeg,
    material: material,
    boot: boot,
    productId: productId,
    psx: psx,
    nominalSizeIn: nominalSizeIn,
    holeSizeIn: holeSizeIn,
  );
}
