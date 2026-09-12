import 'package:flutter/material.dart';

import '../../models/job_spec.dart';
import '../app_scope.dart';
import '../mh_theme.dart';
import '../widgets/dense.dart';

/// Phase 3 - Pipe Schedule. A dense spreadsheet: one row per penetration,
/// every cell tab-reachable.
class PhasePipeSchedule extends StatelessWidget {
  const PhasePipeSchedule({super.key});

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    final validation = design.validation;
    final radiusIn = design.layout.outsideDiameterIn / 2;

    const columns = <(String, int)>[
      ('Pipe', 3),
      ('Type', 3),
      ('O.D. in', 3),
      ('Hole in', 3),
      ('Invert ft', 3),
      ('A-Clock deg', 3),
      ('Clock', 2),
      ('Hole X/Y in', 4),
      ('', 2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionBar(
          title: 'Pipe Schedule - ${design.structureMark}',
          trailing: TextButton(
            key: const Key('btn-add-pipe'),
            onPressed: design.addPipe,
            child: const Text('+ ADD PIPE', style: TextStyle(color: Colors.white)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 640;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!narrow) const GridHeaderRow(columns: columns),
                        for (var i = 0; i < design.pipes.length; i++)
                          _PipeRow(index: i, narrow: narrow, radiusIn: radiusIn, columns: columns),
                      ],
                    );
                  },
                ),
                if (validation.conflicts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(Mh.gap),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEA),
                      border: Border.all(color: Mh.danger, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PENETRATION CONFLICT - ${validation.conflicts.length} ISSUE(S)',
                          style: const TextStyle(
                            color: Mh.danger,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final c in validation.conflicts)
                          Text(
                            '• ${c.message}',
                            style: const TextStyle(color: Mh.danger, fontSize: 11.5),
                          ),
                        for (final n in validation.notices)
                          Text('• $n', style: const TextStyle(color: Mh.danger, fontSize: 11.5)),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.all(Mh.gap),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F5EC),
                      border: Border.all(color: Mh.ok),
                    ),
                    child: const Text(
                      'SPATIAL CHECK PASSED - all penetrations clear by 6" minimum.',
                      style: TextStyle(color: Mh.ok, fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PipeRow extends StatelessWidget {
  const _PipeRow({
    required this.index,
    required this.narrow,
    required this.radiusIn,
    required this.columns,
  });

  final int index;
  final bool narrow;
  final double radiusIn;
  final List<(String, int)> columns;

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    final pipe = design.pipes[index];
    final conflicted = design.conflictedPipeNames.contains(pipe.name);
    final coords = pipe.holeCoordinates(radiusIn);

    final cells = <Widget>[
      DenseField(
        key: Key('pipe-$index-name'),
        value: pipe.name,
        onChanged: (v) => design.updatePipe(index, (p) => p.name = v),
      ),
      DenseDropdown<PipeMaterial>(
        value: pipe.material,
        items: PipeMaterial.values,
        labelOf: (m) => m.label,
        onChanged: (m) => design.updatePipe(index, (p) => p.material = m),
      ),
      DenseField(
        key: Key('pipe-$index-od'),
        value: pipe.outsideDiameterIn.toStringAsFixed(1),
        numeric: true,
        onChanged: (v) {
          final parsed = parseNum(v);
          if (parsed != null) design.updatePipe(index, (p) => p.outsideDiameterIn = parsed);
        },
      ),
      DenseField(
        key: Key('pipe-$index-hole'),
        value: pipe.holeSizeIn.toStringAsFixed(1),
        numeric: true,
        onChanged: (v) {
          final parsed = parseNum(v);
          if (parsed != null) design.updatePipe(index, (p) => p.holeSizeIn = parsed);
        },
      ),
      DenseField(
        key: Key('pipe-$index-invert'),
        value: pipe.invertElevationFt.toStringAsFixed(2),
        numeric: true,
        onChanged: (v) {
          final parsed = parseNum(v);
          if (parsed != null) design.updatePipe(index, (p) => p.invertElevationFt = parsed);
        },
      ),
      DenseField(
        key: Key('pipe-$index-angle'),
        value: pipe.horizontalAngleDeg.toStringAsFixed(0),
        numeric: true,
        onChanged: (v) {
          final parsed = parseNum(v);
          if (parsed != null) design.updatePipe(index, (p) => p.horizontalAngleDeg = parsed);
        },
      ),
      Text(pipe.clockPosition, style: Mh.cellNum),
      Text(
        'E ${coords.eastIn.toStringAsFixed(1)} / N ${coords.northIn.toStringAsFixed(1)}',
        style: Mh.cellNum,
      ),
      IconButton(
        key: Key('pipe-$index-delete'),
        icon: const Icon(Icons.delete_outline, size: 16),
        visualDensity: VisualDensity.compact,
        tooltip: 'Delete pipe',
        onPressed: () => design.removePipeAt(index),
      ),
    ];

    if (!narrow) {
      return GridRow(
        striped: index.isOdd,
        highlight: conflicted ? const Color(0xFFFDECEA) : null,
        cells: [for (var i = 0; i < cells.length; i++) (cells[i], columns[i].$2)],
      );
    }

    // Narrow screens: two stacked grid rows so every cell stays usable.
    return Column(
      children: [
        const GridHeaderRow(columns: [('Pipe', 3), ('Type', 3), ('O.D.', 3), ('Hole', 3), ('', 2)]),
        GridRow(
          highlight: conflicted ? const Color(0xFFFDECEA) : null,
          cells: [(cells[0], 3), (cells[1], 3), (cells[2], 3), (cells[3], 3), (cells[8], 2)],
        ),
        const GridHeaderRow(
          columns: [('Invert', 3), ('A-Clock', 3), ('Clock', 2), ('Hole X/Y', 4)],
        ),
        GridRow(
          highlight: conflicted ? const Color(0xFFFDECEA) : null,
          cells: [(cells[4], 3), (cells[5], 3), (cells[6], 2), (cells[7], 4)],
        ),
        const SizedBox(height: Mh.gap),
      ],
    );
  }
}
