import 'dart:math' as math;

/// A single pipe entering or leaving the structure.
class PipePenetration {
  PipePenetration({
    required this.name,
    required this.outsideDiameterIn,
    required this.invertElevationFt,
    required this.horizontalAngleDeg,
  });

  String name;

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

  PipePenetration copy() => PipePenetration(
        name: name,
        outsideDiameterIn: outsideDiameterIn,
        invertElevationFt: invertElevationFt,
        horizontalAngleDeg: horizontalAngleDeg,
      );
}
