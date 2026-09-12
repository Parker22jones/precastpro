import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/export/submittal_pdf.dart';
import 'package:precastpro/logic/pipe_validator.dart';
import 'package:precastpro/logic/stack_calculator.dart';
import 'package:precastpro/logic/structure_layout.dart';
import 'package:precastpro/models/pipe_penetration.dart';
import 'package:precastpro/models/precast_piece.dart';
import 'package:precastpro/models/structure_size.dart';
import 'package:precastpro/state/design_state.dart';
import 'package:precastpro/painters/elevation_painter.dart';
import 'package:precastpro/ui/drawings_panel.dart';
import 'package:precastpro/ui/widgets/dense.dart';



PipePenetration pipe(double invertFt, {double od = 12, double angle = 0}) => PipePenetration(
  name: 'P',
  outsideDiameterIn: od,
  invertElevationFt: invertFt,
  horizontalAngleDeg: angle,
);

void main() {
  group('pipe invert never breaks into the base floor', () {
    StructureLayout layout({double floorIn = 8}) => StructureLayout(
      stack: const StackCalculator().calculate(
        rimElevationFt: 100,
        invertElevationFt: 90,
        size: StructureSize.round(48),
        conicalTop: false,
        baseFloorThicknessIn: floorIn,
      ),
      rimElevationFt: 100,
      invertElevationFt: 90,
      size: StructureSize.round(48),
      baseFloorThicknessIn: floorIn,
    );

    test('an invert below the floor top is built up to it', () {
      final l = layout();
      expect(l.floorTopElevationFt, closeTo(90 + 8 / 12, 0.0001));
      final low = pipe(88.0);
      expect(l.buildInvertElevationFt(low), closeTo(l.floorTopElevationFt, 0.0001));
      expect(l.isInvertRaised(low), isTrue);
    });

    test('an invert at or above the floor top is left alone', () {
      final l = layout();
      final high = pipe(95.0);
      expect(l.buildInvertElevationFt(high), 95.0);
      expect(l.isInvertRaised(high), isFalse);
      final flush = pipe(l.floorTopElevationFt);
      expect(l.isInvertRaised(flush), isFalse);
    });

    test('a thicker floor raises the limit', () {
      final l = layout(floorIn: 12);
      expect(l.floorTopElevationFt, closeTo(91.0, 0.0001));
      expect(l.buildInvertElevationFt(pipe(90.5)), closeTo(91.0, 0.0001));
    });

    test('the validator reports the buried opening', () {
      final l = layout();
      final report = const PipeValidator().validate(
        pipes: [pipe(88.0)],
        size: StructureSize.round(48),
        floorTopElevationFt: l.floorTopElevationFt,
      );
      expect(report.notices.any((n) => n.toUpperCase().contains('FLOOR')), isTrue);
    });

    test('design state clamps the rendered invert of a sump-deep structure', () {
      final design = DesignState(
        rimElevationFt: 100,
        invertElevationFt: 90,
        sumpDepthIn: 6,
        pipes: [pipe(89.0)],
      );
      final l = design.layout;
      expect(l.floorTopElevationFt, closeTo(90 - 0.5 + 8 / 12, 0.0001));
      expect(l.buildInvertElevationFt(design.pipes.first), l.floorTopElevationFt);
    });
  });

  group('rectangular structures', () {
    final box = StructureSize.rectangular(insideWidthIn: 36, insideLengthIn: 48);

    test('reach hits the flat walls, not a circle', () {
      expect(box.insideReachIn(90), closeTo(18, 0.0001)); // east wall
      expect(box.insideReachIn(0), closeTo(24, 0.0001)); // north wall
      expect(box.outsideReachIn(90), closeTo(18 + kBoxWallThicknessIn, 0.0001));
      expect(box.sizeLabel, '36" x 48" I.D.');
    });

    test('round size keeps a constant reach', () {
      final round = StructureSize.round(48);
      expect(round.insideReachIn(0), closeTo(24, 0.0001));
      expect(round.insideReachIn(37), closeTo(24, 0.0001));
      expect(round.sizeLabel, '48" I.D.');
    });

    test('the catalog builds parametric box pieces that stack', () {
      final set = PieceCatalog.forSize(box);
      expect(set.base.isRectangular, isTrue);
      expect(set.base.insideLengthIn, 48);
      expect(set.base.weightLbs, greaterThan(0));
      final stack = const StackCalculator().calculate(
        rimElevationFt: 100,
        invertElevationFt: 90,
        size: box,
        conicalTop: true,
      );
      expect(stack.feasible, isTrue);
      expect(stack.items.first.piece.type, PieceType.base);
      // Boxes have no conical form, so the design falls back to a flat top.
      expect(stack.items.where((i) => i.piece.type == PieceType.conicalTop), isEmpty);
      expect(stack.messages, isNotEmpty);
    });

    test('design state switches shape and feeds the geometry engines', () {
      final design = DesignState();
      expect(design.size.isRound, isTrue);
      design.structureShape = StructureShape.rectangular;
      design.insideWidthIn = 48;
      design.insideLengthIn = 60;
      expect(design.size.shape, StructureShape.rectangular);
      expect(design.layout.size.insideLengthIn, 60);
      expect(design.stack.feasible, isTrue);
    });

    test('validator measures clearance between box wall points', () {
      final report = const PipeValidator().validate(
        pipes: [pipe(95, od: 18, angle: 90), pipe(95, od: 18, angle: 100)],
        size: box,
      );
      expect(report.conflicts, isNotEmpty);
    });

    test('feet-and-inches entry parses to inches', () {
      expect(parseFeetInches('48'), 48);
      expect(parseFeetInches('48"'), 48);
      expect(parseFeetInches("4'"), 48);
      expect(parseFeetInches("4' 6"), 54);
      expect(parseFeetInches('abc'), isNull);
    });
  });

  group('shape-aware drawings', () {
    testWidgets('both sheets and the submittal render for a box structure', (tester) async {
      final design = DesignState(
        structureShape: StructureShape.rectangular,
        insideWidthIn: 36,
        insideLengthIn: 48,
        pipes: [pipe(88.0, od: 12, angle: 90), pipe(95, od: 12, angle: 180)],
      );
      late Uint8List pdf;
      await tester.runAsync(() async {
        final elevationPng = await renderPainterToPng(
          buildElevationPainter(design),
          const Size(400, 560),
          pixelRatio: 1,
        );
        final planPng = await renderPainterToPng(
          buildPlanPainter(design),
          const Size(400, 400),
          pixelRatio: 1,
        );
        expect(elevationPng.length, greaterThan(1000));
        expect(planPng.length, greaterThan(1000));
        pdf = await buildSubmittalPdf(
          SubmittalData(
            jobName: design.jobName,
            rimElevationFt: design.rimElevationFt,
            invertElevationFt: design.invertElevationFt,
            size: design.size,
            floorThicknessIn: design.baseFloorThicknessIn,
            conicalTop: design.conicalTop,
            stack: design.stack,
            pipes: design.pipes,
            validation: design.validation,
            elevationPng: elevationPng,
            planPng: planPng,
            generatedAt: DateTime(2026, 5, 6),
          ),
        );
      });
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    });

    test('the submittal prints the built invert, not the buried one', () {
      final design = DesignState(pipes: [pipe(80.0)]);
      final data = SubmittalData(
        jobName: design.jobName,
        rimElevationFt: design.rimElevationFt,
        invertElevationFt: design.invertElevationFt,
        size: design.size,
        conicalTop: design.conicalTop,
        stack: design.stack,
        pipes: design.pipes,
        validation: design.validation,
        elevationPng: Uint8List(0),
        planPng: Uint8List(0),
        generatedAt: DateTime(2026, 5, 6),
      );
      expect(
        data.buildInvertElevationFt(design.pipes.first),
        closeTo(design.layout.floorTopElevationFt, 0.0001),
      );
    });
  });
}
