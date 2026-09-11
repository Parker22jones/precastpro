import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/logic/pipe_validator.dart';
import 'package:precastpro/models/pipe_penetration.dart';

PipePenetration pipe(String name, double od, double inv, double angle) => PipePenetration(
      name: name,
      outsideDiameterIn: od,
      invertElevationFt: inv,
      horizontalAngleDeg: angle,
    );

void main() {
  const validator = PipeValidator();

  ValidationReport check(List<PipePenetration> pipes, {double id = 48, double wall = 5}) =>
      validator.validate(pipes: pipes, structureInsideDiameterIn: id, wallThicknessIn: wall);

  test('opposing pipes are clear', () {
    final r = check([pipe('IN', 12, 90, 0), pipe('OUT', 12, 89.8, 180)]);
    expect(r.conflicts, isEmpty);
    expect(r.isClear, isTrue);
  });

  test('overlapping circumferences are flagged as critical', () {
    final r = check([pipe('A', 18, 90, 0), pipe('B', 18, 90, 10)]);
    expect(r.hasCritical, isTrue);
    expect(r.conflicts.single.horizontalClearanceIn, lessThan(0));
    expect(r.conflicts.single.message, contains('OVERLAP'));
  });

  test('pipes closer than 6 inches are flagged as a warning', () {
    // 26.5" mid radius -> arc of 40 deg is ~18.5"; two 12" pipes leave ~6.5".
    final clear = check([pipe('A', 12, 90, 0), pipe('B', 12, 90, 40)]);
    expect(clear.conflicts, isEmpty);

    final tight = check([pipe('A', 12, 90, 0), pipe('B', 12, 90, 35)]);
    expect(tight.conflicts, hasLength(1));
    expect(tight.conflicts.single.severity, ConflictSeverity.warning);
    expect(tight.conflicts.single.horizontalClearanceIn, lessThan(6));
    expect(tight.conflicts.single.horizontalClearanceIn, greaterThan(0));
  });

  test('the 6 inch clearance threshold is exact', () {
    // Mid-wall radius of a 48" ID / 5" wall structure is 26.5"; two 12" pipes
    // are exactly 6" clear when their arc distance is 18".
    final thresholdDeg = (18.0 / 26.5) * 180 / math.pi;

    expect(check([pipe('A', 12, 90, 0), pipe('B', 12, 90, thresholdDeg + 0.05)]).conflicts, isEmpty);

    final tight = check([pipe('A', 12, 90, 0), pipe('B', 12, 90, thresholdDeg - 1)]);
    expect(tight.conflicts, hasLength(1));
    expect(tight.conflicts.single.horizontalClearanceIn, closeTo(5.54, 0.05));
  });

  test('angle wrap-around is measured the short way', () {
    final r = check([pipe('A', 18, 90, 355), pipe('B', 18, 90, 5)]);
    expect(r.hasCritical, isTrue);
  });

  test('pipes on the same angle are acceptable when separated vertically', () {
    final stacked = check([pipe('A', 12, 90, 90), pipe('B', 12, 92, 90)]);
    expect(stacked.conflicts, isEmpty);

    final tooClose = check([pipe('A', 12, 90, 90), pipe('B', 12, 91.2, 90)]);
    expect(tooClose.conflicts, hasLength(1));
  });

  test('three pipes report every offending pair', () {
    final r = check([
      pipe('A', 18, 90, 0),
      pipe('B', 18, 90, 8),
      pipe('C', 18, 90, 16),
    ]);
    expect(r.conflicts.length, 3);
  });

  test('oversized pipe for the structure is reported', () {
    final r = check([pipe('BIG', 42, 90, 0)]);
    expect(r.notices, isNotEmpty);
    expect(r.isClear, isFalse);
  });

  test('pipe outside the rim/invert envelope is reported', () {
    final r = validator.validate(
      pipes: [pipe('LOW', 12, 85, 0), pipe('HIGH', 12, 99.9, 180)],
      structureInsideDiameterIn: 48,
      wallThicknessIn: 5,
      rimElevationFt: 100,
      invertElevationFt: 88,
    );
    expect(r.notices.length, 2);
  });

  test('clock position matches the clockwise angle', () {
    expect(pipe('A', 12, 90, 0).clockPosition, '12:00');
    expect(pipe('A', 12, 90, 90).clockPosition, '3:00');
    expect(pipe('A', 12, 90, 180).clockPosition, '6:00');
    expect(pipe('A', 12, 90, 270).clockPosition, '9:00');
    expect(pipe('A', 12, 90, 405).normalizedAngleDeg, 45);
    expect(pipe('A', 12, 90, -90).normalizedAngleDeg, 270);
  });
}
