import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/main.dart';
import 'package:precastpro/models/component_status.dart';
import 'package:precastpro/models/pipe_penetration.dart';
import 'package:precastpro/models/precast_piece.dart';
import 'package:precastpro/state/app_state.dart';
import 'package:precastpro/state/design_state.dart';
import 'package:precastpro/ui/app_shell.dart';
import 'package:precastpro/ui/drawings_panel.dart';
import 'package:precastpro/ui/inventory_page.dart';
import 'package:precastpro/ui/logistics_page.dart';

AppState stateWith(DesignState design) => AppState(
  structures: [StructureRecord(design: design, components: design.buildComponents())],
);

Future<void> pumpAt(WidgetTester tester, Size size, AppState state) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // The shell opens on the job browser; these cases exercise an open job.
  state.openJob(state.activeJob.id);
  await tester.pumpWidget(PrecastProApp(state: state));
  await tester.pumpAndSettle();
}

Future<void> openModule(WidgetTester tester, Module module, {bool wide = true}) async {
  if (!wide) {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('nav-${module.name}')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop width shows the wizard and drawings side by side', (tester) async {
    await pumpAt(tester, const Size(1600, 1000), AppState());

    expect(find.byKey(const Key('nav-phase1')), findsOneWidget);
    expect(find.byType(DrawingsPanel), findsOneWidget);
    expect(find.byKey(const Key('canvas-elevation')), findsOneWidget);
    expect(find.byKey(const Key('canvas-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone width collapses into data/drawings tabs with a drawer', (tester) async {
    await pumpAt(tester, const Size(390, 844), AppState());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.text('DRAWINGS'), findsOneWidget);

    await tester.tap(find.text('DRAWINGS'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('canvas-elevation')), findsOneWidget);
    expect(find.byKey(const Key('canvas-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout breakpoint helper', (tester) async {
    expect(isWideLayout(1440), isTrue);
    expect(isWideLayout(390), isFalse);
  });

  testWidgets('phase navigation walks all five phases', (tester) async {
    await pumpAt(tester, const Size(1600, 1200), AppState());

    for (final phase in [Module.phase2, Module.phase3, Module.phase4, Module.phase5]) {
      await tester.tap(find.byKey(const Key('btn-phase-next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PHASE ${phase.step} OF 5'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('structural details report the grade rings the stack actually uses', (tester) async {
    final design = DesignState(rimElevationFt: 101, invertElevationFt: 88, sumpDepthIn: 6);
    final rings = design.stack.items
        .where((i) => i.piece.type == PieceType.gradeRing)
        .fold<int>(0, (sum, i) => sum + i.count);
    expect(rings, greaterThan(0));

    await pumpAt(tester, const Size(1600, 1200), stateWith(design));
    await openModule(tester, Module.phase4);

    expect(find.textContaining('$rings ring(s)'), findsOneWidget);
  });

  testWidgets('logistics lists every component row at iPhone width', (tester) async {
    final state = AppState();
    await pumpAt(tester, const Size(390, 844), state);
    await openModule(tester, Module.logistics, wide: false);

    final firstComponent = state.structures.first.components.first;
    expect(find.text(firstComponent.id), findsOneWidget);
    expect(find.byKey(const Key('ship-toggle-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear design shows the spatial pass banner', (tester) async {
    await pumpAt(tester, const Size(1600, 1200), AppState());
    await openModule(tester, Module.phase3);

    expect(find.textContaining('SPATIAL CHECK PASSED'), findsOneWidget);
  });

  testWidgets('conflicting pipes raise the bright warning banner', (tester) async {
    final design = DesignState(
      pipes: [
        PipePenetration(
          name: 'A',
          outsideDiameterIn: 18,
          invertElevationFt: 89,
          horizontalAngleDeg: 0,
        ),
        PipePenetration(
          name: 'B',
          outsideDiameterIn: 18,
          invertElevationFt: 89,
          horizontalAngleDeg: 8,
        ),
      ],
    );
    await pumpAt(tester, const Size(1600, 1200), stateWith(design));
    await openModule(tester, Module.phase3);

    expect(find.textContaining('PENETRATION CONFLICT'), findsOneWidget);
  });

  testWidgets('editing the rim elevation recalculates the stack', (tester) async {
    final design = DesignState();
    await pumpAt(tester, const Size(1600, 1200), stateWith(design));
    await openModule(tester, Module.phase2);

    final before = design.stack.totalWeightLbs;
    await tester.enterText(find.byKey(const Key('field-rim')), '112.0');
    await tester.pumpAndSettle();

    expect(design.rimElevationFt, 112.0);
    expect(design.stack.totalWeightLbs, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding and removing pipes updates the design', (tester) async {
    final design = DesignState();
    await pumpAt(tester, const Size(1600, 1200), stateWith(design));
    await openModule(tester, Module.phase3);

    final initial = design.pipes.length;
    await tester.tap(find.byKey(const Key('btn-add-pipe')));
    await tester.pumpAndSettle();
    expect(design.pipes.length, initial + 1);

    // The dense grid scrolls horizontally; bring the delete cell into view.
    final deleteButton = find.byKey(Key('pipe-${design.pipes.length - 1}-delete'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(design.pipes.length, initial);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logistics dashboard ships a piece and decrements inventory', (tester) async {
    final state = AppState();
    await pumpAt(tester, const Size(1600, 1200), state);
    await openModule(tester, Module.logistics);

    expect(find.byType(LogisticsPage), findsOneWidget);
    final sku = state.activeStructure.components.first.stockSku;
    final before = state.itemForSku(sku)!.onHand;

    await tester.tap(find.byKey(const Key('ship-toggle-0')));
    await tester.pumpAndSettle();

    expect(state.structures.first.components.first.status.hasLeftYard, isTrue);
    expect(state.itemForSku(sku)!.onHand, before - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('low stock shipment raises the amber badge and reminder', (tester) async {
    final state = AppState();
    for (final item in state.inventory) {
      state.setThreshold(item, 0);
    }
    final sku = state.structures.first.components.first.stockSku;
    final item = state.itemForSku(sku)!;
    state.receiveStock(item, -item.onHand + 1);
    state.setThreshold(item, 5);
    state.markNotificationsRead();

    await pumpAt(tester, const Size(1600, 1200), state);

    expect(find.byKey(const Key('badge-low-stock')), findsOneWidget);

    await openModule(tester, Module.inventory);
    expect(find.byType(InventoryPage), findsOneWidget);
    expect(find.byKey(const Key('low-stock-banner')), findsOneWidget);
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
      await pumpAt(tester, size, AppState());
      expect(tester.takeException(), isNull, reason: 'layout failed at $size');
    }
  });
}
