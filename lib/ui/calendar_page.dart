import 'package:flutter/material.dart';

import '../models/component_status.dart';
import '../models/job_spec.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'mh_theme.dart';
import 'status_colors.dart';
import 'widgets/dense.dart';

/// Global production calendar: a month grid of casting lines, the structures
/// scheduled on the selected day across every job, and the priority backlog
/// that can be drafted into that day's run.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.onOpenStructure});

  final VoidCallback onOpenStructure;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selected = _today();
  late DateTime _month = DateTime(_selected.year, _selected.month);
  bool _allJobs = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // The open job's run by default; plant managers widen it to the whole
    // plant explicitly.
    final jobId = _allJobs ? null : app.activeJob.id;
    final calendar = _MonthGrid(
      app: app,
      jobId: jobId,
      scopeLabel: _allJobs ? 'ALL JOBS' : app.activeJob.name,
      onToggleScope: () => setState(() => _allJobs = !_allJobs),
      month: _month,
      selected: _selected,
      onSelect: (day) => setState(() => _selected = day),
      onShiftMonth: (delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
      }),
      onToday: () => setState(() {
        _selected = _today();
        _month = DateTime(_selected.year, _selected.month);
      }),
      onTomorrow: () => setState(() {
        _selected = _today().add(const Duration(days: 1));
        _month = DateTime(_selected.year, _selected.month);
      }),
    );
    final line = _CastingLine(
      app: app,
      jobId: jobId,
      day: _selected,
      onOpenStructure: widget.onOpenStructure,
    );
    final backlog = _Backlog(app: app, jobId: jobId, day: _selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Mh.gap),
                  child: calendar,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Mh.gap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [line, backlog],
                  ),
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(Mh.gap),
          children: [calendar, line, backlog],
        );
      },
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const List<String> _monthNames = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.app,
    required this.jobId,
    required this.scopeLabel,
    required this.onToggleScope,
    required this.month,
    required this.selected,
    required this.onSelect,
    required this.onShiftMonth,
    required this.onToday,
    required this.onTomorrow,
  });

  final AppState app;
  final String? jobId;
  final String scopeLabel;
  final VoidCallback onToggleScope;
  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onShiftMonth;
  final VoidCallback onToday;
  final VoidCallback onTomorrow;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first grid.
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final scheduled = app.castingLineFor(day, jobId: jobId).length;
      final isSelected = day == selected;
      cells.add(
        InkWell(
          key: Key('cal-day-${_fmt(day)}'),
          onTap: () => onSelect(day),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Mh.accent : Mh.field,
              border: Border.all(color: Mh.gridLine),
            ),
            padding: const EdgeInsets.all(2),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Mh.text,
                    ),
                  ),
                ),
                if (scheduled > 0)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      color: isSelected ? Colors.white24 : Mh.headerFill,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '$scheduled cast',
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Mh.subtleText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return SpecPanel(
      title: '${_monthNames[month.month - 1]} ${month.year}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('btn-cal-prev'),
            onTap: () => onShiftMonth(-1),
            child: const Icon(Icons.chevron_left, size: 18, color: Colors.white),
          ),
          InkWell(
            key: const Key('btn-cal-next'),
            onTap: () => onShiftMonth(1),
            child: const Icon(Icons.chevron_right, size: 18, color: Colors.white),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              OutlinedButton(
                key: const Key('btn-cal-today'),
                onPressed: onToday,
                child: const Text('TODAY'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: const Key('btn-cal-tomorrow'),
                onPressed: onTomorrow,
                child: const Text("TOMORROW"),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  key: const Key('btn-cal-scope'),
                  onPressed: onToggleScope,
                  child: Text(
                    scopeLabel.toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(child: Center(child: Text(label, style: Mh.header))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: cells,
          ),
        ),
      ],
    );
  }
}

class _CastingLine extends StatelessWidget {
  const _CastingLine({
    required this.app,
    required this.jobId,
    required this.day,
    required this.onOpenStructure,
  });

  final AppState app;
  final String? jobId;
  final DateTime day;
  final VoidCallback onOpenStructure;

  @override
  Widget build(BuildContext context) {
    final scheduled = app.castingLineFor(day, jobId: jobId);
    final concreteLbs = app.concreteWeightLbsFor(day, jobId: jobId);
    final cuYd = app.pourVolumeCuYdFor(day, jobId: jobId);
    final over = app.isOverPourCapacity(day);

    return SpecPanel(
      title: 'Casting Line ${_fmt(day)} - ${scheduled.length} structures',
      trailing: Flexible(
        child: Text(
          key: const Key('cal-pour-volume'),
          '${cuYd.toStringAsFixed(2)} CY / ${concreteLbs.toStringAsFixed(0)} LB'
          '${over ? ' OVER CAP' : ''}',
          style: Mh.sectionTitle,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
      children: [
        if (scheduled.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Nothing scheduled for this date.', style: Mh.label),
          ),
        if (scheduled.isNotEmpty)
          DenseGrid(
            minWidth: 660,
            rows: [
              const GridHeaderRow(
                columns: [
                  ('Pri', 1),
                  ('Structure', 3),
                  ('Job', 4),
                  ('Type', 3),
                  ('Status', 3),
                  ('Cu yd', 2),
                  ('', 3),
                ],
              ),
              for (var i = 0; i < scheduled.length; i++)
                GridRow(
                  striped: i.isOdd,
                  cells: [
                    (
                      Text(
                        scheduled[i].design.priority == 0 ? '-' : '${scheduled[i].design.priority}',
                        style: Mh.cellNum,
                      ),
                      1,
                    ),
                    (Text(scheduled[i].mark, style: Mh.cell), 3),
                    (Text(scheduled[i].jobName, style: Mh.cell, overflow: TextOverflow.ellipsis), 4),
                    (
                      Text(
                        scheduled[i].design.structureType.label,
                        style: Mh.cell,
                        overflow: TextOverflow.ellipsis,
                      ),
                      3,
                    ),
                    (
                      StatusChip(
                        label: scheduled[i].rollupStatus.label,
                        color: statusColor(scheduled[i].rollupStatus),
                      ),
                      3,
                    ),
                    (
                      Text(
                        scheduled[i].pourVolumeCuYd.toStringAsFixed(2),
                        style: Mh.cellNum,
                      ),
                      2,
                    ),
                    (
                      TextButton(
                        key: Key('cal-open-${scheduled[i].mark}'),
                        onPressed: () {
                          app.selectStructureRecord(scheduled[i]);
                          onOpenStructure();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 22),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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

/// Unpoured work ranked by priority, draftable into the selected day's run.
class _Backlog extends StatelessWidget {
  const _Backlog({required this.app, required this.jobId, required this.day});

  final AppState app;
  final String? jobId;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final backlog = app
        .unpouredBacklog(jobId: jobId)
        .where((r) => r.pourDate != day)
        .toList();

    return SpecPanel(
      title: 'Unpoured Backlog - top priorities',
      children: [
        if (backlog.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No unpoured structures outside this run.', style: Mh.label),
          ),
        if (backlog.isNotEmpty)
          DenseGrid(
            minWidth: 640,
            rows: [
              const GridHeaderRow(
                columns: [
                  ('Pri', 1),
                  ('Structure', 3),
                  ('Job', 4),
                  ('Scheduled', 3),
                  ('', 3),
                ],
              ),
              for (var i = 0; i < backlog.length; i++)
                GridRow(
                  striped: i.isOdd,
                  cells: [
                    (
                      Text(
                        backlog[i].design.priority == 0 ? '-' : '${backlog[i].design.priority}',
                        style: Mh.cellNum,
                      ),
                      1,
                    ),
                    (Text(backlog[i].mark, style: Mh.cell), 3),
                    (Text(backlog[i].jobName, style: Mh.cell, overflow: TextOverflow.ellipsis), 4),
                    (Text(_fmt(backlog[i].pourDate), style: Mh.cellNum), 3),
                    (
                      FilledButton(
                        key: Key('draft-${backlog[i].mark}'),
                        onPressed: () => app.scheduleStructure(backlog[i], day),
                        child: const Text('DRAFT INTO RUN'),
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
