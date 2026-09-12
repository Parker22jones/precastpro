import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import 'app_scope.dart';
import 'mh_theme.dart';
import 'widgets/dense.dart';

/// Inventory management: raw stock and castings, minimum thresholds, and the
/// low-stock alerts raised when shipments draw stock down.
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final low = app.lowStockItems;

    return ListView(
      padding: const EdgeInsets.all(Mh.gap),
      children: [
        if (low.isNotEmpty)
          Container(
            key: const Key('low-stock-banner'),
            margin: const EdgeInsets.only(bottom: Mh.gap),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4DB),
              border: Border.all(color: Mh.warn, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Mh.warn, size: 18),
                const SizedBox(width: 6),
                Text('LOW STOCK ALERT - ${low.length} ITEM(S) AT OR BELOW MINIMUM',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8A5A00))),
              ]),
              const SizedBox(height: 4),
              for (final item in low)
                Text(
                  '• ${item.sku} ${item.description}: ${item.onHand} on hand, '
                  'minimum ${item.minThreshold} - reorder ${item.shortfall}+',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A5A00)),
                ),
            ]),
          ),
        for (final category in StockCategory.values)
          SpecPanel(
            title: category.label,
            children: [
              const GridHeaderRow(columns: [
                ('SKU', 2),
                ('Description', 6),
                ('On Hand', 2),
                ('Min', 2),
                ('Status', 3),
                ('Receive', 3),
              ]),
              for (final entry in _indexed(app.inventory, category))
                GridRow(
                  striped: entry.$1.isOdd,
                  highlight: entry.$2.isLowStock ? const Color(0xFFFFF4DB) : null,
                  cells: [
                    (Text(entry.$2.sku, style: Mh.cell), 2),
                    (Text(entry.$2.description, style: Mh.cell), 6),
                    (Text('${entry.$2.onHand}', style: Mh.cellNum), 2),
                    (
                      DenseField(
                        key: Key('min-${entry.$2.sku}'),
                        value: '${entry.$2.minThreshold}',
                        numeric: true,
                        onChanged: (v) {
                          final parsed = parseNum(v);
                          if (parsed != null) app.setThreshold(entry.$2, parsed.round());
                        },
                      ),
                      2
                    ),
                    (
                      entry.$2.isLowStock
                          ? const StatusChip(label: 'Low Stock', color: Mh.warn)
                          : const StatusChip(label: 'OK', color: Mh.ok),
                      3
                    ),
                    (
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          key: Key('receive-${entry.$2.sku}'),
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Receive 10',
                          onPressed: () => app.receiveStock(entry.$2, 10),
                        ),
                        IconButton(
                          key: Key('issue-${entry.$2.sku}'),
                          icon: const Icon(Icons.remove_circle_outline, size: 16),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Issue 1',
                          onPressed: () => app.receiveStock(entry.$2, -1),
                        ),
                      ]),
                      3
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Iterable<(int, InventoryItem)> _indexed(List<InventoryItem> items, StockCategory category) sync* {
    var i = 0;
    for (final item in items) {
      if (item.category == category) yield (i++, item);
    }
  }
}
