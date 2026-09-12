import 'package:flutter/material.dart';

import '../../models/job_spec.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../mh_theme.dart';
import '../widgets/dense.dart';

/// Phase 1 - Job Info & Spec.
class PhaseJobInfo extends StatelessWidget {
  const PhaseJobInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final design = app.design;

    return ListView(
      padding: const EdgeInsets.all(Mh.gap),
      children: [
        SpecPanel(
          title: 'Job Information',
          children: [
            SpecRow(
              label: 'Project Name',
              child: DenseField(
                key: const Key('field-job-name'),
                value: design.jobName,
                onChanged: (v) => design.jobName = v,
              ),
            ),
            SpecRow(
              label: 'Structure Mark',
              child: DenseField(
                key: const Key('field-structure-mark'),
                value: design.structureMark,
                onChanged: (v) => design.structureMark = v,
              ),
            ),
            SpecRow(
              label: 'Customer',
              child: DenseField(
                key: const Key('field-customer'),
                value: design.customer,
                onChanged: (v) => design.customer = v,
              ),
            ),
            SpecRow(
              label: 'Structure Type',
              child: DenseDropdown<StructureType>(
                value: design.structureType,
                items: StructureType.values,
                labelOf: (t) => t.label,
                onChanged: (t) => design.structureType = t,
              ),
            ),
            SpecRow(
              label: 'Cast Date',
              child: _CastDateCell(app: app),
            ),
          ],
        ),
        SpecPanel(
          title: 'Active Structures',
          trailing: TextButton(
            onPressed: app.addStructure,
            child: const Text('+ NEW STRUCTURE', style: TextStyle(color: Colors.white)),
          ),
          children: [
            const GridHeaderRow(
              columns: [('Mark', 2), ('Job', 4), ('Customer', 3), ('Type', 3), ('', 2)],
            ),
            for (var i = 0; i < app.structures.length; i++)
              GridRow(
                striped: i.isOdd,
                highlight: i == app.activeIndex ? const Color(0xFFDDEBFA) : null,
                cells: [
                  (Text(app.structures[i].mark, style: Mh.cell), 2),
                  (Text(app.structures[i].jobName, style: Mh.cell), 4),
                  (Text(app.structures[i].design.customer, style: Mh.cell), 3),
                  (Text(app.structures[i].design.structureType.label, style: Mh.cell), 3),
                  (
                    i == app.activeIndex
                        ? const StatusChip(label: 'Open', color: Mh.accent)
                        : TextButton(
                            onPressed: () => app.selectStructure(i),
                            child: const Text('OPEN'),
                          ),
                    2,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _CastDateCell extends StatelessWidget {
  const _CastDateCell({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final design = app.design;
    final d = design.castDate;
    final text =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Expanded(
          child: DenseField(
            key: const Key('field-cast-date'),
            value: text,
            onChanged: (v) {
              final parsed = DateTime.tryParse(v.trim());
              if (parsed != null) design.castDate = parsed;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today, size: 15),
          visualDensity: VisualDensity.compact,
          tooltip: 'Pick cast date',
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: design.castDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2040),
            );
            if (picked != null) design.castDate = picked;
          },
        ),
      ],
    );
  }
}
