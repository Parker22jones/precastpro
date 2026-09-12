import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/export/bill_of_materials.dart';
import 'package:precastpro/export/submittal_pdf.dart';
import 'package:precastpro/models/pipe_penetration.dart';
import 'package:precastpro/painters/elevation_painter.dart';
import 'package:precastpro/state/design_state.dart';
import 'package:precastpro/ui/drawings_panel.dart';

void main() {
  test('layout stacks pieces continuously from the base floor to the rim', () {
    final design = DesignState(rimElevationFt: 100, invertElevationFt: 88.5);
    final layout = design.layout;

    expect(layout.pieces, isNotEmpty);
    expect(layout.floorTopElevationFt - layout.floorBottomElevationFt, closeTo(8 / 12, 1e-9));
    for (var i = 1; i < layout.pieces.length; i++) {
      expect(
        layout.pieces[i].bottomElevationFt,
        closeTo(layout.pieces[i - 1].topElevationFt, 1e-9),
      );
    }
    expect(layout.topOfStackElevationFt, closeTo(design.rimElevationFt, 0.01));
    expect(layout.jointElevationsFt.length, layout.pieces.length - 1);
  });

  test('bill of materials groups pieces and totals the weight', () {
    final design = DesignState(rimElevationFt: 104, invertElevationFt: 88);
    final bom = buildBillOfMaterials(design.stack);

    expect(bom.map((l) => l.mark).toSet().length, bom.length);
    expect(bom.fold<int>(0, (s, l) => s + l.count), design.stack.totalPieceCount);
    expect(
      bom.fold<double>(0, (s, l) => s + l.totalWeightLbs),
      closeTo(design.stack.totalWeightLbs, 0.001),
    );
  });

  testWidgets('painters render to PNG and feed a multi-kilobyte PDF', (tester) async {
    final design = DesignState(
      pipes: [
        PipePenetration(
          name: 'IN',
          outsideDiameterIn: 15,
          invertElevationFt: 89.5,
          horizontalAngleDeg: 45,
        ),
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 18,
          invertElevationFt: 88.5,
          horizontalAngleDeg: 225,
        ),
      ],
    );

    // Rasterisation and PDF assembly need real async, not the fake test clock.
    await tester.runAsync(() async {
      final elevationPng = await renderPainterToPng(
        buildElevationPainter(design),
        const Size(600, 800),
        pixelRatio: 1,
      );
      final planPng = await renderPainterToPng(
        buildPlanPainter(design),
        const Size(600, 600),
        pixelRatio: 1,
      );

      expect(elevationPng.length, greaterThan(1000));
      expect(planPng.length, greaterThan(1000));

      final pdf = await buildSubmittalPdf(
        SubmittalData(
          jobName: design.jobName,
          rimElevationFt: design.rimElevationFt,
          invertElevationFt: design.invertElevationFt,
          structureDiameterIn: design.structureDiameterIn,
          conicalTop: design.conicalTop,
          stack: design.stack,
          pipes: design.pipes,
          validation: design.validation,
          elevationPng: elevationPng,
          planPng: planPng,
          generatedAt: DateTime(2026, 1, 2),
        ),
      );

      expect(pdf.length, greaterThan(5000));
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    });
  });

  test('stack pieces are lettered top down for the sheet callouts', () {
    final design = DesignState(rimElevationFt: 104, invertElevationFt: 88);
    final layout = design.layout;
    final marks = layout.pieceMarks;

    expect(marks.values.toSet().length, marks.length);
    expect(marks[layout.pieces.last.piece.id], 'A');
    expect(marks[layout.pieces.first.piece.id], String.fromCharCode(64 + marks.length));
  });

  testWidgets('sheets scale to any canvas without throwing', (tester) async {
    final design = DesignState(
      pipes: [
        PipePenetration(
          name: '#1',
          outsideDiameterIn: 12,
          invertElevationFt: 89,
          horizontalAngleDeg: 0,
        ),
        PipePenetration(
          name: '#2',
          outsideDiameterIn: 12,
          invertElevationFt: 89,
          horizontalAngleDeg: 187,
        ),
      ],
    );

    await tester.runAsync(() async {
      for (final size in const [Size(200, 200), Size(1400, 420), Size(360, 900)]) {
        expect(
          await renderPainterToPng(buildElevationPainter(design), size, pixelRatio: 1),
          isNotEmpty,
        );
        expect(
          await renderPainterToPng(buildPlanPainter(design), size, pixelRatio: 1),
          isNotEmpty,
        );
      }
    });
  });

  testWidgets('painters survive degenerate input without throwing', (tester) async {
    final design = DesignState(rimElevationFt: 90, invertElevationFt: 90, pipes: []);

    await tester.runAsync(() async {
      final elevation = await renderPainterToPng(
        buildElevationPainter(design),
        const Size(300, 300),
        pixelRatio: 1,
      );
      final plan = await renderPainterToPng(
        buildPlanPainter(design),
        const Size(300, 300),
        pixelRatio: 1,
      );
      expect(elevation, isNotEmpty);
      expect(plan, isNotEmpty);
    });
  });
}
