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
    final job = app.activeJob;
    final structures = app.alphabeticalStructures(job.id);

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
              label: 'Job Number',
              child: DenseField(
                key: const Key('field-job-number'),
                value: job.number,
                onChanged: (v) => app.updateJob(job, number: v),
              ),
            ),
            SpecRow(
              label: 'Contractor',
              child: DenseField(
                key: const Key('field-contractor'),
                value: job.contractor,
                onChanged: (v) => app.updateJob(job, contractor: v),
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
          ],
        ),
        SpecPanel(
          title: 'Structures in this Job',
          trailing: TextButton(
            onPressed: app.addStructure,
            child: const Text('+ NEW STRUCTURE', style: TextStyle(color: Colors.white)),
          ),
          children: [
            const GridHeaderRow(
              columns: [('Mark', 3), ('Type', 4), ('Flows Into', 3), ('Cast', 3), ('', 3)],
            ),
            for (var i = 0; i < structures.length; i++)
              GridRow(
                striped: i.isOdd,
                highlight: identical(structures[i], app.activeStructure)
                    ? const Color(0xFFDDEBFA)
                    : null,
                cells: [
                  (Text(structures[i].mark, style: Mh.cell), 3),
                  (Text(structures[i].design.structureType.label, style: Mh.cell), 4),
                  (Text(structures[i].design.downstreamMark ?? '-', style: Mh.cell), 3),
                  (Text(_date(structures[i].design.castDate), style: Mh.cellNum), 3),
                  (
                    identical(structures[i], app.activeStructure)
                        ? const StatusChip(label: 'Open', color: Mh.accent)
                        : TextButton(
                            key: Key('open-structure-${structures[i].mark}'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: const Size(0, 22),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => app.selectStructureRecord(structures[i]),
                            child: const Text('OPEN', maxLines: 1, softWrap: false),
                          ),
                    3,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Cast date entry with a picker - shared by the job and structure screens.
class CastDateCell extends StatelessWidget {
  const CastDateCell({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final design = app.design;
    final text = _date(design.castDate);
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
