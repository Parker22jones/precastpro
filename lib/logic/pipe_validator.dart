import 'dart:math' as math;

import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';
import '../models/structure_size.dart';

enum ConflictSeverity { warning, critical }

class PipeConflict {
  const PipeConflict({
    required this.pipeA,
    required this.pipeB,
    required this.severity,
    required this.message,
    required this.horizontalClearanceIn,
    required this.verticalClearanceIn,
  });

  final String pipeA;
  final String pipeB;
  final ConflictSeverity severity;
  final String message;

  /// Clear distance between the two openings measured along the wall
  /// circumference, in inches. Negative means the openings overlap.
  final double horizontalClearanceIn;

  /// Clear vertical distance between the two openings, in inches.
  final double verticalClearanceIn;
}

class ValidationReport {
  const ValidationReport({required this.conflicts, required this.notices});

  final List<PipeConflict> conflicts;

  /// Non pipe-to-pipe issues (pipe outside the structure, oversized pipe...).
  final List<String> notices;

  bool get hasCritical => conflicts.any((c) => c.severity == ConflictSeverity.critical);
  bool get hasWarning => conflicts.isNotEmpty || notices.isNotEmpty;
  bool get isClear => !hasWarning;
}

/// Spatial safety checks for pipe penetrations in a round or box structure.
class PipeValidator {
  const PipeValidator({this.minClearanceIn = kMinPipeClearanceIn});

  final double minClearanceIn;

  ValidationReport validate({
    required List<PipePenetration> pipes,
    required StructureSize size,
    double? rimElevationFt,
    double? invertElevationFt,
    double? floorTopElevationFt,
  }) {
    final conflicts = <PipeConflict>[];
    final notices = <String>[];

    final maxOpening = size.maxOpeningIn;

    for (final p in pipes) {
      if (p.outsideDiameterIn <= 0) {
        notices.add('${p.name}: outside diameter must be greater than zero.');
      } else if (p.outsideDiameterIn > maxOpening) {
        notices.add(
          '${p.name}: ${p.outsideDiameterIn.toStringAsFixed(1)}" OD exceeds 75% of the '
          '${size.sizeLabel} structure - use a larger structure or a doghouse base.',
        );
      }
      if (floorTopElevationFt != null && p.invertElevationFt < floorTopElevationFt - 0.001) {
        notices.add(
          '${p.name}: invert ${p.invertElevationFt.toStringAsFixed(2)} is below the top of the '
          'base floor (${floorTopElevationFt.toStringAsFixed(2)}) - opening raised flush with the slab.',
        );
      } else if (invertElevationFt != null && p.invertElevationFt < invertElevationFt - 0.01) {
        notices.add('${p.name}: invert is below the structure invert elevation.');
      }
      if (rimElevationFt != null &&
          p.invertElevationFt + p.outsideDiameterIn / 12 > rimElevationFt) {
        notices.add('${p.name}: crown of pipe is above the rim elevation.');
      }
    }

    for (var i = 0; i < pipes.length; i++) {
      for (var j = i + 1; j < pipes.length; j++) {
        final a = pipes[i];
        final b = pipes[j];

        final horizontalClear =
            _wallDistanceIn(size, a, b) - (a.outsideDiameterIn + b.outsideDiameterIn) / 2;

        final verticalCenterDistance =
            (a.centerlineElevationFt - b.centerlineElevationFt).abs() * 12.0;
        final verticalClear =
            verticalCenterDistance - (a.outsideDiameterIn + b.outsideDiameterIn) / 2;

        // Openings only conflict when they are tight both horizontally and
        // vertically - stacked pipes on the same angle are acceptable when they
        // are far enough apart vertically.
        if (horizontalClear >= minClearanceIn || verticalClear >= minClearanceIn) continue;

        final overlapping = horizontalClear < 0 && verticalClear < 0;
        conflicts.add(
          PipeConflict(
            pipeA: a.name,
            pipeB: b.name,
            severity: overlapping ? ConflictSeverity.critical : ConflictSeverity.warning,
            horizontalClearanceIn: horizontalClear,
            verticalClearanceIn: verticalClear,
            message: overlapping
                ? 'OPENINGS OVERLAP: ${a.name} (${a.clockPosition}) and ${b.name} (${b.clockPosition}) '
                      'intersect by ${horizontalClear.abs().toStringAsFixed(1)}" horizontally and '
                      '${verticalClear.abs().toStringAsFixed(1)}" vertically.'
                : 'TOO CLOSE: ${a.name} (${a.clockPosition}) and ${b.name} (${b.clockPosition}) have only '
                      '${math.max(horizontalClear, verticalClear).toStringAsFixed(1)}" of clear wall - '
                      '${minClearanceIn.toStringAsFixed(0)}" minimum required.',
          ),
        );
      }
    }

    return ValidationReport(conflicts: conflicts, notices: notices);
  }

  /// Distance between two openings measured on the wall surface: along the
  /// circumference of a round barrel, straight across the faces of a box.
  double _wallDistanceIn(StructureSize size, PipePenetration a, PipePenetration b) {
    if (size.isRound) {
      var delta = (a.normalizedAngleDeg - b.normalizedAngleDeg).abs();
      if (delta > 180) delta = 360 - delta;
      final midRadius = size.insideDiameterIn / 2 + size.wallThicknessIn / 2;
      return midRadius * delta * math.pi / 180.0;
    }
    final pa = size.wallPoint(a.normalizedAngleDeg);
    final pb = size.wallPoint(b.normalizedAngleDeg);
    return math.sqrt(
      math.pow(pa.eastIn - pb.eastIn, 2) + math.pow(pa.northIn - pb.northIn, 2),
    );
  }
}
