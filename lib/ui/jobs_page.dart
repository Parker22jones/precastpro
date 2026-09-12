import 'package:flutter/material.dart';

import '../logic/flow_tree.dart';
import '../models/component_status.dart';
import '../models/job.dart';
import '../models/job_spec.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'mh_theme.dart';
import 'status_colors.dart';
import 'widgets/dense.dart';

/// The landing screen: nothing but the searchable global job list. No
/// structure data is shown until a job is explicitly opened, which is how
/// MH Pro! scopes a session to one project database at a time.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key, required this.onOpenJob});

  /// Invoked once a job has been opened, to leave the browser.
  final VoidCallback onOpenJob;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final results = app.searchJobs(_search.text);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: _JobsPanel(
          app: app,
          jobs: results,
          controller: _search,
          onQueryChanged: () => setState(() {}),
          onSelect: (j) {
            app.openJob(j.id);
            widget.onOpenJob();
          },
        ),
      ),
    );
  }
}

/// Inside an open job: its structures A-Z beside the drainage flow tree,
/// plus the shop priority ranking. Only the open job's data is reachable.
class JobOverviewPage extends StatelessWidget {
  const JobOverviewPage({super.key, required this.onOpenStructure});

  /// Invoked after a structure is selected, to jump into the wizard.
  final VoidCallback onOpenStructure;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final job = app.activeJob;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Mh.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _JobHeader(app: app, job: job),
          _JobTree(app: app, job: job, onOpenStructure: onOpenStructure),
          _PriorityPanel(app: app, job: job),
        ],
      ),
    );
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.app, required this.job});

  final AppState app;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final structures = app.structuresForJob(job.id);
    return SpecPanel(
      title: 'Job ${job.number} - ${job.name}',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            '${job.contractor}  •  ${job.customer}  •  ${structures.length} structures',
            style: Mh.label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _JobsPanel extends StatelessWidget {
  const _JobsPanel({
    required this.app,
    required this.jobs,
    required this.controller,
    required this.onQueryChanged,
    required this.onSelect,
  });

  final AppState app;
  final List<Job> jobs;
  final TextEditingController controller;
  final VoidCallback onQueryChanged;
  final ValueChanged<Job> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        SectionBar(
          title: 'Jobs (${jobs.length})',
          trailing: InkWell(
            key: const Key('btn-add-job'),
            onTap: () => onSelect(app.addJob()),
            child: const Text('+ NEW', style: Mh.sectionTitle),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: TextField(
            key: const Key('field-job-search'),
            controller: controller,
            autofocus: true,
            style: Mh.cell,
            decoration: const InputDecoration(
              hintText: 'Search job name, number or contractor',
              prefixIcon: Icon(Icons.search, size: 16),
              prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            onChanged: (_) => onQueryChanged(),
          ),
        ),
        if (jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text('No jobs match that search.', style: Mh.label),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: jobs.length,
          itemBuilder: (context, i) {
            final job = jobs[i];
            final count = app.structuresForJob(job.id).length;
            return InkWell(
              key: Key('job-row-${job.id}'),
              onTap: () => onSelect(job),
              child: Container(
                decoration: const BoxDecoration(
                  color: Mh.field,
                  border: Border(bottom: BorderSide(color: Mh.gridLine)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  job.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(job.number, style: Mh.cellNum),
                            ],
                          ),
                          Text(
                            '${job.contractor}  •  $count structures',
                            style: Mh.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: Key('btn-open-job-${job.id}'),
                      onPressed: () => onSelect(job),
                      child: const Text('OPEN', maxLines: 1, softWrap: false),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _JobTree extends StatelessWidget {
  const _JobTree({required this.app, required this.job, required this.onOpenStructure});

  final AppState app;
  final Job job;
  final VoidCallback onOpenStructure;

  void _open(StructureRecord record) {
    app.selectStructureRecord(record);
    onOpenStructure();
  }

  @override
  Widget build(BuildContext context) {
    final alpha = app.alphabeticalStructures(job.id);
    final tree = app.flowTree(job.id);

    final alphaPanel = SpecPanel(
      title: 'Structures A-Z',
      trailing: InkWell(
        key: const Key('btn-add-structure'),
        onTap: () => app.addStructure(jobId: job.id),
        child: const Text('+ ADD', style: Mh.sectionTitle),
      ),
      children: [
        if (alpha.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No structures yet.', style: Mh.label),
          ),
        for (final record in alpha)
          _StructureRow(
            key: Key('alpha-${record.mark}'),
            record: record,
            selected: identical(record, app.activeStructure),
            indent: 0,
            onTap: () => _open(record),
          ),
      ],
    );

    final flowPanel = SpecPanel(
      title: 'Flow Order (downstream first)',
      children: [
        if (tree.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No structures yet.', style: Mh.label),
          ),
        for (final node in tree) ..._flowRows(node, 0),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: alphaPanel),
              const SizedBox(width: Mh.gap),
              Expanded(child: flowPanel),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [alphaPanel, flowPanel],
        );
      },
    );
  }

  List<Widget> _flowRows(FlowNode<StructureRecord> node, int depth) => [
    _StructureRow(
      key: Key('flow-${node.mark}'),
      record: node.value,
      selected: identical(node.value, app.activeStructure),
      indent: depth,
      onTap: () => _open(node.value),
    ),
    for (final child in node.children) ..._flowRows(child, depth + 1),
  ];
}

class _StructureRow extends StatelessWidget {
  const _StructureRow({
    super.key,
    required this.record,
    required this.selected,
    required this.indent,
    required this.onTap,
  });

  final StructureRecord record;
  final bool selected;
  final int indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Mh.rowHeight),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDEBFA) : Mh.field,
          border: const Border(bottom: BorderSide(color: Mh.gridLine)),
        ),
        padding: EdgeInsets.fromLTRB(8.0 + indent * 16, 4, 8, 4),
        child: Row(
          children: [
            if (indent > 0) const Icon(Icons.subdirectory_arrow_right, size: 13, color: Mh.subtleText),
            Expanded(
              child: Text(
                record.mark,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('RIM ${record.design.rimElevationFt.toStringAsFixed(2)}', style: Mh.label),
            const SizedBox(width: 6),
            StatusChip(label: record.rollupStatus.label, color: statusColor(record.rollupStatus)),
          ],
        ),
      ),
    );
  }
}

/// Numeric + drag-and-drop ranking of the job's structures for the shop.
class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({required this.app, required this.job});

  final AppState app;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final ordered = app.prioritizedStructures(job.id);
    return SpecPanel(
      title: 'Shop Priority - drag to rank',
      children: [
        if (ordered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No structures yet.', style: Mh.label),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: ordered.length,
          onReorder: (from, to) => app.reorderPriority(job.id, from, to),
          itemBuilder: (context, i) {
            final record = ordered[i];
            return Container(
              key: Key('priority-${record.mark}'),
              decoration: const BoxDecoration(
                color: Mh.field,
                border: Border(bottom: BorderSide(color: Mh.gridLine)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text('${i + 1}', style: Mh.cellNum),
                  ),
                  Expanded(
                    child: Text(
                      '${record.mark} - ${record.design.structureType.label}',
                      style: Mh.cell,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: DenseField(
                      key: Key('priority-rank-${record.mark}'),
                      value: '${record.design.priority}',
                      numeric: true,
                      onChanged: (raw) {
                        final rank = int.tryParse(raw.trim());
                        if (rank != null) record.design.priority = rank;
                      },
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.drag_handle, size: 16, color: Mh.subtleText),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
