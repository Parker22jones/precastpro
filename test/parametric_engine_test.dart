import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/logic/pipe_validator.dart';
import 'package:precastpro/logic/stack_calculator.dart';
import 'package:precastpro/models/pipe_penetration.dart';
import 'package:precastpro/models/precast_piece.dart';
import 'package:precastpro/models/structure_size.dart';
import 'package:precastpro/state/app_state.dart';
import 'package:precastpro/state/design_state.dart';

void main() {
  group('parametric wall thickness', () {
    test('round walls follow the diameter', () {
      expect(StructureSize.round(48).wallThicknessIn, 5);
      expect(StructureSize.round(60).wallThicknessIn, 6);
    });

    test('box walls step from 6 to 8 inches with the clear span', () {
      expect(
        StructureSize.rectangular(insideWidthIn: 36, insideLengthIn: 48).wallThicknessIn,
        6,
      );
      expect(
        StructureSize.rectangular(insideWidthIn: 48, insideLengthIn: 96).wallThicknessIn,
        8,
      );
    });

    test('changing the design dimension re-derives the wall', () {
      final design = DesignState(structureDiameterIn: 48);
      expect(design.wallThicknessIn, 5);
      design.structureDiameterIn = 60;
      expect(design.wallThicknessIn, 6);
      expect(design.size.outsideWidthIn, 60 + 12);
    });

    test('a manual wall overrides until a dimension changes', () {
      final design = DesignState(structureDiameterIn: 48);
      design.wallThicknessIn = 7;
      expect(design.isWallStandard, isFalse);
      expect(design.size.wallThicknessIn, 7);
      design.structureDiameterIn = 60;
      expect(design.isWallStandard, isTrue);
      expect(design.wallThicknessIn, 6);
    });
  });

  group('sump drives the base section', () {
    test('a round base grows in height and weight with the sump', () {
      final plain = PieceCatalog.baseFor(StructureSize.round(48));
      final sumped = PieceCatalog.baseFor(StructureSize.round(48), sumpDepthIn: 12);
      expect(sumped.heightIn, closeTo(plain.heightIn + 12, 0.001));
      expect(sumped.weightLbs, greaterThan(plain.weightLbs));
    });

    test('a box base grows in height and weight with the sump', () {
      final size = StructureSize.rectangular(insideWidthIn: 48, insideLengthIn: 60);
      final plain = PieceCatalog.baseFor(size);
      final sumped = PieceCatalog.baseFor(size, sumpDepthIn: 6);
      expect(sumped.heightIn, closeTo(plain.heightIn + 6, 0.001));
      expect(sumped.weightLbs, greaterThan(plain.weightLbs));
    });

    test('the stack carries the deeper base through to the total weight', () {
      const calc = StackCalculator();
      final plain = calc.calculate(
        rimElevationFt: 100,
        invertElevationFt: 90,
        size: StructureSize.round(48),
        conicalTop: false,
      );
      final sumped = calc.calculate(
        rimElevationFt: 100,
        invertElevationFt: 90,
        size: StructureSize.round(48),
        conicalTop: false,
        sumpDepthIn: 12,
      );
      expect(sumped.items.first.piece.heightIn, closeTo(plain.items.first.piece.heightIn + 12, 0.001));
      expect(sumped.totalWeightLbs, greaterThan(plain.totalWeightLbs));
    });
  });

  group('box wall penetrations', () {
    final size = StructureSize.rectangular(insideWidthIn: 48, insideLengthIn: 48);

    test('the entry angle picks the wall face', () {
      expect(size.wallFaceFor(0), BoxWall.north);
      expect(size.wallFaceFor(90), BoxWall.east);
      expect(size.wallFaceFor(180), BoxWall.south);
      expect(size.wallFaceFor(270), BoxWall.west);
      expect(StructureSize.round(48).wallFaceFor(45), isNull);
    });

    test('skew is measured off the wall normal', () {
      expect(size.skewDegFor(0), closeTo(0, 0.001));
      expect(size.skewDegFor(30), closeTo(30, 0.001));
      expect(size.skewDegFor(120), closeTo(30, 0.001));
    });

    test('a skewed opening cuts a wider slot in the wall', () {
      expect(size.wallCutWidthIn(12, 0), closeTo(12, 0.001));
      // 60° clockwise leaves the east wall 30° off its normal.
      expect(size.wallCutWidthIn(12, 60), closeTo(12 / 0.8660, 0.01));
      expect(size.wallCutWidthIn(12, 45), greaterThan(size.wallCutWidthIn(12, 20)));
    });

    test('an extreme skew is flagged for the shop', () {
      final report = const PipeValidator().validate(
        pipes: [
          PipePenetration(
            name: 'IN-A',
            outsideDiameterIn: 12,
            invertElevationFt: 95,
            horizontalAngleDeg: 70,
          ),
        ],
        // A wide, shallow box: a 70° heading grazes the north wall.
        size: StructureSize.rectangular(insideWidthIn: 120, insideLengthIn: 36),
      );
      expect(report.notices.any((n) => n.toUpperCase().contains('SKEW')), isTrue);
    });
  });

  group('daily pour volume', () {
    test('a day totals concrete only, in pounds and cubic yards', () {
      final app = AppState();
      final day = app.structures.first.pourDate;
      final scheduled = app.castingLineFor(day);
      expect(scheduled, isNotEmpty);

      final expectedLbs = scheduled.fold(0.0, (s, r) => s + r.design.stack.totalWeightLbs);
      expect(app.concreteWeightLbsFor(day), closeTo(expectedLbs, 0.001));
      expect(
        app.pourVolumeCuYdFor(day),
        closeTo(expectedLbs / (kConcreteDensityPcf * 27), 0.001),
      );
      // Castings, boots and steps are pulled from stock, not batched.
      final payloadLbs = scheduled.fold<double>(0.0, (s, r) => s + r.totalWeightLbs);
      expect(app.concreteWeightLbsFor(day), lessThan(payloadLbs));
    });

    test('multiple structures scheduled on the same day add up', () {
      final app = AppState();
      final day = AppState.tomorrow;
      final before = app.tomorrowCastingLine.length;
      final moved = app.structures.where((r) => r.pourDate != day).take(2).toList();
      for (final r in moved) {
        r.design.castDate = day;
      }
      final line = app.tomorrowCastingLine;
      expect(line.length, before + moved.length);
      expect(
        app.tomorrowPourVolumeCuYd,
        closeTo(line.fold<double>(0.0, (s, r) => s + r.pourVolumeCuYd), 0.001),
      );
    });

    test('an empty day books no concrete', () {
      final app = AppState();
      final empty = AppState.tomorrow.add(const Duration(days: 400));
      expect(app.concreteWeightLbsFor(empty), 0);
      expect(app.isOverPourCapacity(empty), isFalse);
    });
  });
}
