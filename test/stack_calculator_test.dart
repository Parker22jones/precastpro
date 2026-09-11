import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/logic/stack_calculator.dart';
import 'package:precastpro/models/precast_piece.dart';

void main() {
  const calc = StackCalculator();

  test('structural depth is rim minus invert minus the 8 inch base floor', () {
    expect(
      StackCalculator.structuralDepthIn(rimElevationFt: 100, invertElevationFt: 90),
      120 - 8,
    );
  });

  test('stack reaches the rim exactly and totals the structural depth', () {
    final r = calc.calculate(
      rimElevationFt: 100,
      invertElevationFt: 88.5,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    expect(r.feasible, isTrue);
    expect(r.structuralDepthIn, closeTo(130, 0.001));
    expect(r.achievedHeightIn, closeTo(r.structuralDepthIn, 0.001));
    expect(r.isExact, isTrue);
    expect(r.residualIn.abs(), lessThan(0.01));
  });

  test('always starts with a base section and carries exactly one top', () {
    final r = calc.calculate(
      rimElevationFt: 104,
      invertElevationFt: 90,
      structureDiameterIn: 60,
      conicalTop: false,
    );
    expect(r.items.first.piece.type, PieceType.base);
    expect(r.items.first.piece.insideDiameterIn, 60);
    expect(r.items.where((i) => i.piece.type == PieceType.flatTop).length, 1);
    expect(r.items.where((i) => i.piece.type == PieceType.conicalTop), isEmpty);
  });

  test('grade rings sit above the top and never below it', () {
    final r = calc.calculate(
      rimElevationFt: 100.5,
      invertElevationFt: 89,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    final topIndex = r.items.indexWhere(
      (i) => i.piece.type == PieceType.conicalTop || i.piece.type == PieceType.flatTop,
    );
    final gradeRingIndexes = [
      for (var i = 0; i < r.items.length; i++)
        if (r.items[i].piece.type == PieceType.gradeRing) i,
    ];
    for (final i in gradeRingIndexes) {
      expect(i, greaterThan(topIndex));
    }
  });

  test('minimizes joints: 48 inches of fill uses one 48 inch riser', () {
    // base 48 + conical 36 = 84; + 48 riser = 132 -> rim - invert = 140 in.
    final r = calc.calculate(
      rimElevationFt: 100 + 140 / 12,
      invertElevationFt: 100,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    expect(r.isExact, isTrue);
    final risers = r.items.where((i) => i.piece.type == PieceType.riser).toList();
    expect(risers.length, 1);
    expect(risers.single.count, 1);
    expect(risers.single.piece.heightIn, 48);
    expect(r.totalPieceCount, 3);
    expect(r.jointCount, 2);
  });

  test('uses grade rings only for the remainder that risers cannot make', () {
    // base 48 + conical 36 = 84, remainder 26 -> 24" riser + 2" grade ring.
    final r = calc.calculate(
      rimElevationFt: 100 + (84 + 26 + 8) / 12,
      invertElevationFt: 100,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    expect(r.isExact, isTrue);
    final rings = r.items.where((i) => i.piece.type == PieceType.gradeRing);
    expect(rings.fold<double>(0, (s, i) => s + i.totalHeightIn), 2);
    final risers = r.items.where((i) => i.piece.type == PieceType.riser);
    expect(risers.fold<double>(0, (s, i) => s + i.totalHeightIn), 24);
  });

  test('reports an odd inch remainder instead of silently rounding', () {
    // remainder of 1" cannot be built from 2/4/6" rings or 12" risers.
    final r = calc.calculate(
      rimElevationFt: 100 + (84 + 1 + 8) / 12,
      invertElevationFt: 100,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    expect(r.isExact, isFalse);
    expect(r.residualIn, closeTo(1, 0.001));
    expect(r.messages, isNotEmpty);
  });

  test('flags a structure that is too shallow for a base plus top', () {
    final r = calc.calculate(
      rimElevationFt: 92,
      invertElevationFt: 90,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    expect(r.feasible, isFalse);
    expect(r.messages, isNotEmpty);
  });

  test('rim below invert is rejected', () {
    final r = calc.calculate(
      rimElevationFt: 89,
      invertElevationFt: 90,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    expect(r.feasible, isFalse);
    expect(r.items, isEmpty);
  });

  test('total weight equals the sum of the piece weights', () {
    final r = calc.calculate(
      rimElevationFt: 100,
      invertElevationFt: 88.5,
      structureDiameterIn: 48,
      conicalTop: true,
    );
    final expected = r.items.fold<double>(0, (s, i) => s + i.piece.weightLbs * i.count);
    expect(r.totalWeightLbs, closeTo(expected, 0.001));
    expect(r.totalWeightLbs, greaterThan(0));
  });

  test('catalog exposes every required standard piece', () {
    for (final d in PieceCatalog.availableDiameters) {
      expect(PieceCatalog.risers(d).map((p) => p.heightIn).toSet(), {12.0, 24.0, 36.0, 48.0});
      expect(PieceCatalog.base(d).heightIn, greaterThan(0));
      expect(PieceCatalog.top(d, conical: true).weightLbs, greaterThan(0));
      expect(PieceCatalog.top(d, conical: false).weightLbs, greaterThan(0));
      expect(PieceCatalog.base(d).wallThicknessIn, greaterThan(0));
    }
    expect(PieceCatalog.gradeRings().map((p) => p.heightIn).toSet(), {2.0, 4.0, 6.0});
  });
}
