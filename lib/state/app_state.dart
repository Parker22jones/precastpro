import 'package:flutter/foundation.dart';

import '../models/component_status.dart';
import '../models/inventory_item.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import 'design_state.dart';

/// A structure that has been released from engineering into the yard: its
/// design plus the physical components tracked through the lifecycle.
class StructureRecord {
  StructureRecord({required this.design, required this.components});

  final DesignState design;
  final List<StructureComponent> components;

  String get mark => design.structureMark;
  String get jobName => design.jobName;
  double get totalWeightLbs => components.fold(0.0, (s, c) => s + c.weightLbs);

  int countWithStatus(ComponentStatus status) => components.where((c) => c.status == status).length;

  /// Furthest-behind component status, i.e. what the structure as a whole is
  /// waiting on.
  ComponentStatus get rollupStatus => components.isEmpty
      ? ComponentStatus.pendingPour
      : components.map((c) => c.status).reduce((a, b) => a.index <= b.index ? a : b);
}

/// An in-app reminder raised by the inventory engine.
class StockNotification {
  StockNotification({required this.sku, required this.message, required this.raisedAt});

  final String sku;
  final String message;
  final DateTime raisedAt;
  bool read = false;
}

/// Top-level store: every job's structures, the yard inventory, and the
/// reactive link between them.
class AppState extends ChangeNotifier {
  AppState({List<StructureRecord>? structures, List<InventoryItem>? inventory})
    : _inventory = inventory ?? defaultInventory(),
      _structures = structures ?? [] {
    if (_structures.isEmpty) _seed();
    for (final record in _structures) {
      record.design.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (final record in _structures) {
      record.design.removeListener(notifyListeners);
    }
    super.dispose();
  }

  final List<StructureRecord> _structures;
  final List<InventoryItem> _inventory;
  final List<StockNotification> _notifications = [];
  int _activeIndex = 0;

  List<StructureRecord> get structures => List.unmodifiable(_structures);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  List<StockNotification> get notifications => List.unmodifiable(_notifications);
  List<StockNotification> get unreadNotifications =>
      _notifications.where((n) => !n.read).toList(growable: false);
  List<InventoryItem> get lowStockItems =>
      _inventory.where((i) => i.isLowStock).toList(growable: false);

  int get activeIndex => _activeIndex;
  StructureRecord get activeStructure => _structures[_activeIndex];

  /// The design currently open in the engineering wizard.
  DesignState get design => activeStructure.design;

  void selectStructure(int index) {
    if (index < 0 || index >= _structures.length || index == _activeIndex) return;
    _activeIndex = index;
    notifyListeners();
  }

  /// Re-issues the active structure's component list from the current design.
  /// Components already past "Pending Pour" keep their status where the id and
  /// piece still match, so a late design tweak does not wipe yard progress.
  void releaseActiveStructureToYard() {
    final record = activeStructure;
    final previous = {for (final c in record.components) c.id: c};
    final rebuilt = record.design.buildComponents();
    for (final component in rebuilt) {
      final old = previous[component.id];
      if (old != null && old.pieceId == component.pieceId) {
        component.status = old.status;
      }
    }
    record.components
      ..clear()
      ..addAll(rebuilt);
    notifyListeners();
  }

  void addStructure({String? jobName, String? mark, String? customer}) {
    final n = _structures.length + 1;
    final design = DesignState(
      jobName: jobName ?? 'New Job ${n.toString().padLeft(2, '0')}',
      structureMark: mark ?? 'MH-$n',
      customer: customer ?? 'TBD',
    );
    design.addListener(notifyListeners);
    _structures.add(StructureRecord(design: design, components: design.buildComponents()));
    _activeIndex = _structures.length - 1;
    notifyListeners();
  }

  /// Advances (or rolls back) one component. Crossing into "Shipped" consumes
  /// the matching stock item; rolling back out of "Shipped" returns it.
  void setComponentStatus(
    StructureRecord record,
    StructureComponent component,
    ComponentStatus status,
  ) {
    final was = component.status;
    if (was == status) return;
    component.status = status;

    if (!was.hasLeftYard && status.hasLeftYard) {
      _consumeStock(component.stockSku);
    } else if (was.hasLeftYard && !status.hasLeftYard) {
      _returnStock(component.stockSku);
    }
    notifyListeners();
  }

  void advanceComponent(StructureRecord record, StructureComponent component) {
    final next = component.status.next;
    if (next != null) setComponentStatus(record, component, next);
  }

  /// Yard manager shortcut: ship (or un-ship) every component of a structure.
  void setStructureShipped(StructureRecord record, bool shipped) {
    for (final component in record.components) {
      if (shipped && !component.status.hasLeftYard) {
        setComponentStatus(record, component, ComponentStatus.shipped);
      } else if (!shipped && component.status.hasLeftYard) {
        setComponentStatus(record, component, ComponentStatus.inYard);
      }
    }
  }

  InventoryItem? itemForSku(String sku) {
    for (final item in _inventory) {
      if (item.sku == sku) return item;
    }
    return null;
  }

  void setThreshold(InventoryItem item, int threshold) {
    item.minThreshold = threshold < 0 ? 0 : threshold;
    _checkLowStock(item);
    notifyListeners();
  }

  void receiveStock(InventoryItem item, int quantity) {
    item.onHand += quantity;
    if (item.onHand < 0) item.onHand = 0;
    if (item.isLowStock) {
      _checkLowStock(item);
    } else {
      _notifications.removeWhere((n) => n.sku == item.sku);
    }
    notifyListeners();
  }

  void markNotificationsRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void _consumeStock(String sku) {
    final item = itemForSku(sku);
    if (item == null) return;
    item.onHand = item.onHand > 0 ? item.onHand - 1 : 0;
    _checkLowStock(item);
  }

  void _returnStock(String sku) {
    final item = itemForSku(sku);
    if (item == null) return;
    item.onHand += 1;
    if (!item.isLowStock) _notifications.removeWhere((n) => n.sku == item.sku);
  }

  void _checkLowStock(InventoryItem item) {
    if (!item.isLowStock) return;
    if (_notifications.any((n) => n.sku == item.sku && !n.read)) return;
    _notifications.add(
      StockNotification(
        sku: item.sku,
        message:
            '${item.description} is at ${item.onHand} on hand '
            '(minimum ${item.minThreshold}). Reorder ${item.shortfall} or more.',
        raisedAt: DateTime.now(),
      ),
    );
  }

  void _seed() {
    final mh1 = DesignState(
      jobName: 'Riverbend Interceptor',
      structureMark: 'MH-1',
      customer: 'City of Springfield',
      structureType: StructureType.sanitaryManhole,
      rimElevationFt: 100.0,
      invertElevationFt: 88.5,
    );
    final mh2 = DesignState(
      jobName: 'Riverbend Interceptor',
      structureMark: 'MH-2',
      customer: 'City of Springfield',
      structureType: StructureType.sanitaryManhole,
      rimElevationFt: 102.5,
      invertElevationFt: 89.0,
      structureDiameterIn: 60,
      conicalTop: false,
      pipes: [
        PipePenetration(
          name: 'IN-A',
          outsideDiameterIn: 18,
          invertElevationFt: 90.0,
          horizontalAngleDeg: 45,
          material: PipeMaterial.rcp,
        ),
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 24,
          invertElevationFt: 89.0,
          horizontalAngleDeg: 225,
          material: PipeMaterial.rcp,
        ),
      ],
    );
    final cb1 = DesignState(
      jobName: 'Northgate Retail Pad',
      structureMark: 'CB-1',
      customer: 'Northgate Developers',
      structureType: StructureType.catchBasin,
      rimElevationFt: 96.0,
      invertElevationFt: 90.0,
      sumpDepthIn: 12,
      conicalTop: false,
      pipes: [
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 15,
          invertElevationFt: 90.0,
          horizontalAngleDeg: 270,
          material: PipeMaterial.hdpe,
        ),
      ],
    );

    for (final design in [mh1, mh2, cb1]) {
      _structures.add(StructureRecord(design: design, components: design.buildComponents()));
    }

    // Give the yard a realistic starting spread of progress.
    final first = _structures.first.components;
    for (var i = 0; i < first.length; i++) {
      first[i].status = i < 3
          ? ComponentStatus.inYard
          : i < 6
          ? ComponentStatus.manufactured
          : ComponentStatus.pendingPour;
    }
  }
}
