import 'dart:math' as math;

import 'job_spec.dart';

/// A single pipe entering or leaving the structure.
class PipePenetration {
  PipePenetration({
    required this.name,
    required this.outsideDiameterIn,
    required this.invertElevationFt,
    required this.horizontalAngleDeg,
    this.material = PipeMaterial.pvc,
    this.boot = BootType.aLok,
    double? holeSizeIn,
  }) : holeSizeIn = holeSizeIn ?? outsideDiameterIn + 4;

  String name;

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
        holeSizeIn: holeSizeIn,
      );
}
