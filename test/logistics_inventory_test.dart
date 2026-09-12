import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/models/component_status.dart';
import 'package:precastpro/models/inventory_item.dart';
import 'package:precastpro/models/job_spec.dart';
import 'package:precastpro/state/app_state.dart';
import 'package:precastpro/state/design_state.dart';

AppState singleStructure({int stepCount = 2}) {
  final design = DesignState(structureMark: 'MH-9', stepCount: stepCount);
  return AppState(
    structures: [StructureRecord(design: design, components: design.buildComponents())],
  );
}

void main() {
  group('component lifecycle', () {
    test('components cover concrete, castings, boots and steps', () {
      final app = singleStructure();
      final record = app.activeStructure;
      final skus = record.components.map((c) => c.stockSku).toSet();

      expect(record.components, isNotEmpty);
      expect(skus, contains('LID-24'));
      expect(skus, contains('STEP-MA'));
      expect(skus, contains(BootType.aLok.sku));
      expect(record.components.where((c) => c.stockSku == 'STEP-MA').length, 2);
      expect(record.components.map((c) => c.id).toSet().length, record.components.length);
    });

    test('advancing walks the explicit status chain', () {
      final app = singleStructure();
      final record = app.activeStructure;
      final component = record.components.first;

      expect(component.status, ComponentStatus.pendingPour);
      for (final expected in const [
        ComponentStatus.manufactured,
        ComponentStatus.inYard,
        ComponentStatus.shipped,
        ComponentStatus.delivered,
      ]) {
        app.advanceComponent(record, component);
        expect(component.status, expected);
      }
      app.advanceComponent(record, component);
      expect(component.status, ComponentStatus.delivered);
    });

    test('rollup reports the furthest-behind piece', () {
      final app = singleStructure();
      final record = app.activeStructure;
      for (final c in record.components) {
        c.status = ComponentStatus.inYard;
      }
      record.components.last.status = ComponentStatus.manufactured;
      expect(record.rollupStatus, ComponentStatus.manufactured);
    });

    test('re-issuing to the yard preserves progress on unchanged pieces', () {
      final app = singleStructure();
      final record = app.activeStructure;
      record.components.first.status = ComponentStatus.inYard;

      app.releaseActiveStructureToYard();

      expect(record.components.first.status, ComponentStatus.inYard);
    });
  });

  group('inventory engine', () {
    test('shipping decrements the matching stock item exactly once', () {
      final app = singleStructure();
      final record = app.activeStructure;
      final component = record.components.firstWhere((c) => c.stockSku == 'LID-24');
      final item = app.itemForSku('LID-24')!;
      final before = item.onHand;

      app.setComponentStatus(record, component, ComponentStatus.shipped);
      expect(item.onHand, before - 1);

      // Shipped -> Delivered stays outside the yard: no second decrement.
      app.setComponentStatus(record, component, ComponentStatus.delivered);
      expect(item.onHand, before - 1);
    });

    test('rolling a shipped piece back into the yard returns the stock', () {
      final app = singleStructure();
      final record = app.activeStructure;
      final component = record.components.firstWhere((c) => c.stockSku == 'LID-24');
      final item = app.itemForSku('LID-24')!;
      final before = item.onHand;

      app.setComponentStatus(record, component, ComponentStatus.shipped);
      app.setComponentStatus(record, component, ComponentStatus.inYard);

      expect(item.onHand, before);
    });

    test('shipping a whole structure draws every component sku down', () {
      final app = singleStructure();
      final record = app.activeStructure;
      final steps = app.itemForSku('STEP-MA')!;
      final before = steps.onHand;

      app.setStructureShipped(record, true);

      expect(record.components.every((c) => c.status.hasLeftYard), isTrue);
      expect(steps.onHand, before - 2);
    });

    test('crossing the minimum threshold raises one amber alert', () {
      final item = InventoryItem(
        sku: 'LID-24',
        description: '24" iron lid',
        category: StockCategory.casting,
        onHand: 2,
        minThreshold: 1,
      );
      final design = DesignState(structureMark: 'MH-9', stepCount: 0);
      final app = AppState(
        structures: [StructureRecord(design: design, components: design.buildComponents())],
        inventory: [item],
      );
      final record = app.activeStructure;
      final lids = record.components.where((c) => c.stockSku == 'LID-24').toList();

      app.setComponentStatus(record, lids.first, ComponentStatus.shipped);
      expect(item.onHand, 1);
      expect(item.isLowStock, isTrue);
      expect(app.lowStockItems, contains(item));
      expect(app.unreadNotifications.length, 1);
      expect(app.unreadNotifications.single.sku, 'LID-24');

      // No duplicate reminder while the first one is unread.
      app.setThreshold(item, 1);
      expect(app.unreadNotifications.length, 1);

      // Restocking above the minimum clears the alert.
      app.receiveStock(item, 10);
      expect(item.isLowStock, isFalse);
      expect(app.lowStockItems, isEmpty);
      expect(app.notifications, isEmpty);
    });

    test('manually issuing stock below the minimum also raises a reminder', () {
      final app = singleStructure();
      final item = app.itemForSku('LID-24')!;
      app.setThreshold(item, 5);
      app.receiveStock(item, -item.onHand + 6);
      app.markNotificationsRead();
      expect(item.isLowStock, isFalse);

      app.receiveStock(item, -1);

      expect(item.isLowStock, isTrue);
      expect(app.unreadNotifications.single.sku, 'LID-24');
    });

    test('unknown skus never throw', () {
      final app = singleStructure();
      final record = app.activeStructure;
      final component = record.components.first;
      expect(() => app.setComponentStatus(record, component, ComponentStatus.shipped),
          returnsNormally);
    });
  });

  group('multi-job store', () {
    test('seeded store tracks several jobs and switches the active design', () {
      final app = AppState();
      expect(app.structures.length, greaterThan(1));
      expect(app.structures.map((s) => s.jobName).toSet().length, greaterThan(1));

      app.selectStructure(1);
      expect(app.design, same(app.structures[1].design));
    });

    test('adding a structure makes it active with its own components', () {
      final app = AppState();
      final before = app.structures.length;
      app.addStructure(jobName: 'Harbor Lift', mark: 'MH-77');

      expect(app.structures.length, before + 1);
      expect(app.design.structureMark, 'MH-77');
      expect(app.activeStructure.components, isNotEmpty);
    });
  });
}
