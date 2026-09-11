import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/main.dart';
import 'package:precastpro/models/pipe_penetration.dart';
import 'package:precastpro/state/design_state.dart';
import 'package:precastpro/ui/drawings_panel.dart';
import 'package:precastpro/ui/home_page.dart';
import 'package:precastpro/ui/inputs_panel.dart';

Future<void> pumpAt(WidgetTester tester, Size size, DesignState design) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PrecastProApp(design: design));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop width shows inputs and drawings side by side', (tester) async {
    await pumpAt(tester, const Size(1600, 1000), DesignState());

    expect(find.byType(InputsPanel), findsOneWidget);
    expect(find.byType(DrawingsPanel), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('canvas-elevation')), findsOneWidget);
    expect(find.byKey(const Key('canvas-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone width collapses into two swipeable tabs', (tester) async {
    await pumpAt(tester, const Size(390, 844), DesignState());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Inputs'), findsOneWidget);
    expect(find.text('Drawings'), findsOneWidget);
    // Inputs tab is visible first, drawings live in the second tab.
    expect(find.byType(InputsPanel), findsOneWidget);

    await tester.tap(find.text('Drawings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('canvas-elevation')), findsOneWidget);
    expect(find.byKey(const Key('canvas-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout breakpoint helper', (tester) async {
    expect(isWideLayout(1440), isTrue);
    expect(isWideLayout(390), isFalse);
  });

  testWidgets('clear design shows the green pass banner', (tester) async {
    await pumpAt(tester, const Size(1600, 1000), DesignState());
    expect(find.byKey(const Key('validation-ok')), findsOneWidget);
    expect(find.byKey(const Key('validation-warning')), findsNothing);
  });

  testWidgets('conflicting pipes raise the bright warning banner', (tester) async {
    final design = DesignState(pipes: [
      PipePenetration(name: 'A', outsideDiameterIn: 18, invertElevationFt: 89, horizontalAngleDeg: 0),
      PipePenetration(name: 'B', outsideDiameterIn: 18, invertElevationFt: 89, horizontalAngleDeg: 8),
    ]);
    await pumpAt(tester, const Size(1600, 1000), design);

    expect(find.byKey(const Key('validation-warning')), findsOneWidget);
    expect(find.textContaining('MANUFACTURING CONFLICT'), findsOneWidget);
  });

  testWidgets('editing the rim elevation recalculates the stack', (tester) async {
    final design = DesignState();
    await pumpAt(tester, const Size(1600, 1200), design);

    final before = design.stack.totalWeightLbs;
    await tester.enterText(find.byKey(const Key('field-rim')), '112.0');
    await tester.pumpAndSettle();

    expect(design.rimElevationFt, 112.0);
    expect(design.stack.totalWeightLbs, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding and removing pipes updates the design', (tester) async {
    final design = DesignState();
    await pumpAt(tester, const Size(1600, 1200), design);

    final initial = design.pipes.length;
    await tester.tap(find.byKey(const Key('button-add-pipe')));
    await tester.pumpAndSettle();
    expect(design.pipes.length, initial + 1);

    design.removePipeAt(design.pipes.length - 1);
    await tester.pumpAndSettle();
    expect(design.pipes.length, initial);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at a range of window sizes', (tester) async {
    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(834, 1112),
      Size(1280, 800),
      Size(1920, 1080),
      Size(2560, 1440),
    ]) {
      await pumpAt(tester, size, DesignState());
      expect(tester.takeException(), isNull, reason: 'layout failed at $size');
    }
  });
}
