import 'package:flutter/material.dart';

import '../models/component_status.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'mh_theme.dart';
import 'status_colors.dart';
import 'widgets/dense.dart';

/// Global logistics dashboard: every physical piece of every structure across
/// all active jobs, with per-piece lifecycle control and a ship toggle.
class LogisticsPage extends StatefulWidget {
  const LogisticsPage({super.key});

  @override
  State<LogisticsPage> createState() => _LogisticsPageState();
}

class _LogisticsPageState extends State<LogisticsPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final structures = app.structures;
    final index = _selected.clamp(0, structures.length - 1);
    final record = structures[index];

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final list = _StructureList(
        structures: structures,
        selected: index,
        onSelect: (i) => setState(() => _selected = i),
      );
      final detail = _StructureDetail(app: app, record: record);

      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 320, child: list),
          const VerticalDivider(width: 1),
          Expanded(child: detail),
        ]);
      }
      return ListView(children: [
        SizedBox(height: 40.0 + structures.length * 46, child: list),
        detail,
      ]);
    });
  }
}

class _StructureList extends StatelessWidget {
  const _StructureList({required this.structures, required this.selected, required this.onSelect});

  final List<StructureRecord> structures;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionBar(title: 'Active Structures'),
      Expanded(
        child: ListView.builder(
          itemCount: structures.length,
          itemBuilder: (context, i) {
            final record = structures[i];
            final selectedRow = i == selected;
            return InkWell(
              key: Key('logistics-structure-$i'),
              onTap: () => onSelect(i),
              child: Container(
                decoration: BoxDecoration(
                  color: selectedRow ? const Color(0xFFDDEBFA) : Mh.field,
                  border: const Border(bottom: BorderSide(color: Mh.gridLine)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${record.mark}  -  ${record.jobName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(
                        '${record.components.length} pieces  •  '
                        '${record.countWithStatus(ComponentStatus.shipped)} shipped',
                        style: Mh.label,
                      ),
                    ]),
                  ),
                  StatusChip(
                      label: record.rollupStatus.label, color: statusColor(record.rollupStatus)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _StructureDetail extends StatelessWidget {
  const _StructureDetail({required this.app, required this.record});

  final AppState app;
  final StructureRecord record;

  @override
  Widget build(BuildContext context) {
    final allShipped = record.components.isNotEmpty &&
        record.components.every((c) => c.status.hasLeftYard);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionBar(
        title: 'Piece Tracking - ${record.mark} (${record.jobName})',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('SHIP ALL', style: Mh.sectionTitle),
          Switch(
            key: const Key('toggle-ship-structure'),
            value: allShipped,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => app.setStructureShipped(record, v),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          children: [
            const GridHeaderRow(columns: [
              ('Tag', 2),
              ('Component', 5),
              ('SKU', 2),
              ('Weight lb', 2),
              ('Status', 4),
              ('Shipped', 2),
            ]),
            for (var i = 0; i < record.components.length; i++)
              GridRow(
                striped: i.isOdd,
                cells: [
                  (Text(record.components[i].id, style: Mh.cell), 2),
                  (Text(record.components[i].description, style: Mh.cell), 5),
                  (Text(record.components[i].stockSku, style: Mh.cell), 2),
                  (Text(record.components[i].weightLbs.toStringAsFixed(0), style: Mh.cellNum), 2),
                  (
                    DenseDropdown<ComponentStatus>(
                      value: record.components[i].status,
                      items: ComponentStatus.values,
                      labelOf: (s) => s.label,
                      onChanged: (s) => app.setComponentStatus(record, record.components[i], s),
                    ),
                    4
                  ),
                  (
                    Switch(
                      key: Key('ship-toggle-$i'),
                      value: record.components[i].status.hasLeftYard,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => app.setComponentStatus(
                        record,
                        record.components[i],
                        v ? ComponentStatus.shipped : ComponentStatus.inYard,
                      ),
                    ),
                    2
                  ),
                ],
              ),
          ],
        ),
      ),
    ]);
  }
}
