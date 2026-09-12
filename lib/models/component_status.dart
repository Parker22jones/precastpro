/// Manufacturing lifecycle of one physical piece of concrete.
enum ComponentStatus { pendingPour, manufactured, inYard, shipped, delivered }

extension ComponentStatusInfo on ComponentStatus {
  String get label => switch (this) {
    ComponentStatus.pendingPour => 'Pending Pour',
    ComponentStatus.manufactured => 'Manufactured',
    ComponentStatus.inYard => 'In Yard',
    ComponentStatus.shipped => 'Shipped',
    ComponentStatus.delivered => 'Delivered',
  };

  /// Next step in the lifecycle, or null at the end of the line.
  ComponentStatus? get next {
    const order = ComponentStatus.values;
    final i = order.indexOf(this);
    return i == order.length - 1 ? null : order[i + 1];
  }

  /// True once the piece has physically left the yard.
  bool get hasLeftYard => index >= ComponentStatus.shipped.index;
}

/// One physical piece belonging to a structure, tracked through the yard.
class StructureComponent {
  StructureComponent({
    required this.id,
    required this.pieceId,
    required this.description,
    required this.weightLbs,
    required this.stockSku,
    this.status = ComponentStatus.pendingPour,
  });

  /// Unique within a structure, e.g. "MH-1-03".
  final String id;

  /// Catalog piece id, or a stock casting id for non-concrete items.
  final String pieceId;
  final String description;
  final double weightLbs;

  /// Inventory SKU decremented when this component ships.
  final String stockSku;

  ComponentStatus status;
}
