import 'package:flutter/material.dart';

import '../../models/job_spec.dart';
import '../../models/pipe_penetration.dart';
import '../../models/pipe_product.dart';
import '../../models/structure_size.dart';
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
      ('Type', 2),
      ('Product', 5),
      ('Nom in', 2),
      ('O.D. in', 2),
      ('Hole in', 2),
      ('Invert ft', 3),
      ('A-Clock deg', 3),
      ('Clock', 2),
      ('Connector', 5),
      ('Hole X/Y in', 4),
      ('Wall / cut in', 4),
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
                    final rows = <Widget>[
                      if (!narrow) const GridHeaderRow(columns: columns),
                      for (var i = 0; i < design.pipes.length; i++)
                        _PipeRow(index: i, narrow: narrow, radiusIn: radiusIn, columns: columns),
                    ];
                    if (narrow) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
                    }
                    return DenseGrid(minWidth: 1180, rows: rows);
                  },
                ),
                SpecPanel(
                  title: 'Annular Space Schedule',
                  children: [
                    const GridHeaderRow(
                      columns: [('Pipe', 3), ('Connector', 4), ('Seal Specification', 8)],
                    ),
                    for (var i = 0; i < design.pipes.length; i++)
                      GridRow(
                        striped: i.isOdd,
                        cells: [
                          (Text(design.pipes[i].name, style: Mh.cell), 3),
                          (
                            Text(
                              design.pipes[i].psx.isSleeve
                                  ? design.pipes[i].psx.label
                                  : design.pipes[i].boot.label,
                              style: Mh.cell,
                            ),
                            4,
                          ),
                          (
                            Text(
                              design.pipes[i].sealSpec,
                              key: Key('seal-spec-$i'),
                              style: Mh.cell,
                            ),
                            8,
                          ),
                        ],
                      ),
                  ],
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
                if (validation.notices.isNotEmpty)
                  Container(
                    key: const Key('pipe-notices'),
                    margin: const EdgeInsets.symmetric(horizontal: Mh.gap),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E5),
                      border: Border.all(color: Mh.warn),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHOP NOTES - ${validation.notices.length}',
                          style: const TextStyle(
                            color: Mh.warn,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                        for (final n in validation.notices)
                          Text('• $n', style: const TextStyle(color: Mh.warn, fontSize: 11.5)),
                      ],
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

/// Wall face the pipe cuts and the width of that cut, which stretches with
/// the skew on a box; a round barrel is always cored radially.
String _cutText(StructureSize size, PipePenetration pipe) {
  final face = size.wallFaceFor(pipe.normalizedAngleDeg);
  if (face == null) return 'RADIAL ${pipe.holeSizeIn.toStringAsFixed(1)}';
  final skew = size.skewDegFor(pipe.normalizedAngleDeg);
  final cut = size.wallCutWidthIn(pipe.holeSizeIn, pipe.normalizedAngleDeg);
  return '${face.label} ${cut.toStringAsFixed(1)} @ ${skew.toStringAsFixed(0)}\u00B0';
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
      DenseDropdown<String>(
        key: Key('pipe-$index-product'),
        value: pipe.productId ?? '',
        items: ['', ...kPipeProducts.map((p) => p.id)],
        labelOf: (id) => id.isEmpty ? 'Custom' : productById(id)!.label,
        onChanged: (id) {
          final selected = productById(id);
          design.updatePipe(index, (p) {
            if (selected == null) {
              p.productId = null;
            } else {
              p.applyProduct(selected, p.nominalSizeIn ?? p.outsideDiameterIn.roundToDouble());
            }
          });
        },
      ),
      DenseField(
        key: Key('pipe-$index-nominal'),
        value: (pipe.nominalSizeIn ?? pipe.outsideDiameterIn).toStringAsFixed(0),
        numeric: true,
        onChanged: (v) {
          final parsed = parseNum(v);
          if (parsed == null) return;
          design.updatePipe(index, (p) {
            final selected = p.product;
            if (selected == null) {
              p.nominalSizeIn = parsed;
            } else {
              p.applyProduct(selected, parsed);
            }
          });
        },
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
        // Enter at the end of the last line starts the next penetration.
        onSubmitted: (_) {
          if (index == design.pipes.length - 1) {
            design.addPipe();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        onChanged: (v) {
          final parsed = parseNum(v);
          if (parsed != null) design.updatePipe(index, (p) => p.horizontalAngleDeg = parsed);
        },
      ),
      Text(pipe.clockPosition, style: Mh.cellNum),
      DenseDropdown<PsxConnector>(
        key: Key('pipe-$index-psx'),
        value: pipe.psx,
        items: PsxConnector.values,
        labelOf: (c) => c.label,
        onChanged: (c) => design.updatePipe(index, (p) => p.applyPsx(c)),
      ),
      Text(
        'E ${coords.eastIn.toStringAsFixed(1)} / N ${coords.northIn.toStringAsFixed(1)}',
        style: Mh.cellNum,
      ),
      Text(
        key: Key('pipe-$index-cut'),
        _cutText(design.size, pipe),
        style: Mh.cellNum,
      ),
      IconButton(
        key: Key('pipe-$index-delete'),
        icon: const Icon(Icons.delete_outline, size: 16),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 22),
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

    // Narrow screens: stacked grid rows so every cell stays usable.
    final highlight = conflicted ? const Color(0xFFFDECEA) : null;
    return Column(
      children: [
        const GridHeaderRow(columns: [('Pipe', 3), ('Type', 3), ('O.D.', 3), ('Hole', 3), ('', 2)]),
        GridRow(
          highlight: highlight,
          cells: [(cells[0], 3), (cells[1], 3), (cells[4], 3), (cells[5], 3), (cells[12], 2)],
        ),
        const GridHeaderRow(
          columns: [('Invert', 3), ('A-Clock', 3), ('Hole X/Y', 4), ('Wall / cut', 4)],
        ),
        GridRow(
          highlight: highlight,
          cells: [(cells[6], 3), (cells[7], 3), (cells[10], 4), (cells[11], 4)],
        ),
        const GridHeaderRow(columns: [('Product', 4), ('Nom', 2), ('Connector', 5)]),
        GridRow(
          highlight: highlight,
          cells: [(cells[2], 4), (cells[3], 2), (cells[9], 5)],
        ),
        const SizedBox(height: Mh.gap),
      ],
    );
  }
}
