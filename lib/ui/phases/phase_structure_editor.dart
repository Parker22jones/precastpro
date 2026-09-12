import 'package:flutter/material.dart';

import '../../models/casting_catalog.dart';
import '../../models/job_spec.dart';
import '../../models/pipe_penetration.dart';
import '../../models/pipe_product.dart';
import '../../models/precast_piece.dart';
import '../../models/structure_size.dart';
import '../app_scope.dart';
import '../mh_theme.dart';
import '../widgets/dense.dart';
import 'phase_job_info.dart';

/// Everything editable about one structure on a single screen: identity,
/// shape and size, elevations, top and castings, and the openings grid.
class PhaseStructureEditor extends StatelessWidget {
  const PhaseStructureEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final design = app.design;
    final siblings = app
        .alphabeticalStructures(design.jobId)
        .map((s) => s.mark)
        .where((m) => m != design.structureMark)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(Mh.gap),
      children: [
        SpecPanel(
          title: 'Structure ${design.structureMark}',
          children: [
            SpecRow(
              label: 'Structure Name',
              child: DenseField(
                key: const Key('field-structure-mark'),
                value: design.structureMark,
                onChanged: (v) => design.structureMark = v,
              ),
            ),
            SpecRow(
              label: 'Structure Type',
              child: DenseDropdown<StructureType>(
                key: const Key('field-structure-type'),
                value: design.structureType,
                items: StructureType.values,
                labelOf: (t) => t.label,
                onChanged: (t) => design.structureType = t,
              ),
            ),
            SpecRow(
              label: 'Flows Into',
              child: DenseDropdown<String>(
                key: const Key('field-downstream'),
                value: design.downstreamMark ?? '',
                items: ['', ...siblings],
                labelOf: (m) => m.isEmpty ? 'None (outfall)' : m,
                onChanged: (m) => design.downstreamMark = m,
              ),
            ),
            SpecRow(
              label: 'Shop Priority',
              child: DenseField(
                key: const Key('field-priority'),
                value: '${design.priority}',
                numeric: true,
                onChanged: (v) {
                  final rank = int.tryParse(v.trim());
                  if (rank != null) design.priority = rank;
                },
              ),
            ),
            const SpecRow(label: 'Cast Date', child: CastDateCell()),
          ],
        ),
        const _SizingPanel(),
        const _ElevationsPanel(),
        const _TopAndCastingsPanel(),
        const _OpeningsPanel(),
        const _BuildUpPanel(),
      ],
    );
  }
}

/// Shape and dimensions - the parametric inputs that drive wall thickness,
/// section weights and every drawing.
class _SizingPanel extends StatelessWidget {
  const _SizingPanel();

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;

    return SpecPanel(
      title: 'Shape & Sizing',
      children: [
        SpecRow(
          label: 'Structure Shape',
          child: DenseDropdown<StructureShape>(
            key: const Key('field-shape'),
            value: design.structureShape,
            items: StructureShape.values,
            labelOf: (s) => s.label,
            onChanged: (s) => design.structureShape = s,
          ),
        ),
        if (design.structureShape == StructureShape.round)
          SpecRow(
            label: 'Inside Diameter',
            child: DenseDropdown<double>(
              key: const Key('field-diameter'),
              value: design.structureDiameterIn,
              items: const [48, 60],
              labelOf: (d) => '${d.toStringAsFixed(0)}" I.D.',
              onChanged: (d) => design.structureDiameterIn = d,
            ),
          )
        else ...[
          SpecRow(
            label: 'Inside Width (in)',
            child: DenseField(
              key: const Key('field-inside-width'),
              value: design.insideWidthIn.toStringAsFixed(1),
              dimension: true,
              onChanged: (v) {
                final parsed = parseFeetInches(v);
                if (parsed != null) design.insideWidthIn = parsed;
              },
            ),
          ),
          SpecRow(
            label: 'Inside Length (in)',
            child: DenseField(
              key: const Key('field-inside-length'),
              value: design.insideLengthIn.toStringAsFixed(1),
              dimension: true,
              onChanged: (v) {
                final parsed = parseFeetInches(v);
                if (parsed != null) design.insideLengthIn = parsed;
              },
            ),
          ),
        ],
        SpecRow(
          label: 'Wall Thickness (in)',
          child: Row(
            children: [
              Expanded(
                child: DenseField(
                  key: Key(
                    'field-wall-${design.structureShape.name}-'
                    '${design.size.insideWidthIn.round()}x${design.size.insideLengthIn.round()}',
                  ),
                  value: design.wallThicknessIn.toStringAsFixed(1),
                  numeric: true,
                  onChanged: (v) {
                    final parsed = parseNum(v);
                    if (parsed != null) design.wallThicknessIn = parsed;
                  },
                ),
              ),
              const SizedBox(width: 6),
              design.isWallStandard
                  ? const StatusChip(label: 'ASTM std', color: Mh.ok)
                  : InkWell(
                      key: const Key('btn-wall-standard'),
                      onTap: design.resetWallToStandard,
                      child: StatusChip(
                        label: 'custom - reset to '
                            '${design.standardWallThicknessIn.toStringAsFixed(0)}"',
                        color: Mh.warn,
                      ),
                    ),
            ],
          ),
        ),
        SpecRow(
          label: design.structureShape == StructureShape.round
              ? 'Outside Diameter'
              : 'Outside W x L',
          child: Text(
            design.structureShape == StructureShape.round
                ? '${design.size.outsideWidthIn.toStringAsFixed(0)}"'
                : '${design.size.outsideWidthIn.toStringAsFixed(0)}" x '
                      '${design.size.outsideLengthIn.toStringAsFixed(0)}"',
            style: Mh.cellNum,
          ),
        ),
        SpecRow(
          label: 'Base Floor (in)',
          child: DenseField(
            key: const Key('field-floor'),
            value: design.baseFloorThicknessIn.toStringAsFixed(1),
            numeric: true,
            onChanged: (v) {
              final parsed = parseNum(v);
              if (parsed != null) design.baseFloorThicknessIn = parsed;
            },
          ),
        ),
      ],
    );
  }
}

class _ElevationsPanel extends StatelessWidget {
  const _ElevationsPanel();

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;

    return SpecPanel(
      title: 'Elevations',
      children: [
        SpecRow(
          label: 'Rim Elevation (ft)',
          child: DenseField(
            key: const Key('field-rim'),
            value: design.rimElevationFt.toStringAsFixed(2),
            numeric: true,
            onChanged: (v) {
              final parsed = parseNum(v);
              if (parsed != null) design.rimElevationFt = parsed;
            },
          ),
        ),
        SpecRow(
          label: 'Outlet Invert (ft)',
          child: DenseField(
            key: const Key('field-invert'),
            value: design.invertElevationFt.toStringAsFixed(2),
            numeric: true,
            onChanged: (v) {
              final parsed = parseNum(v);
              if (parsed != null) design.invertElevationFt = parsed;
            },
          ),
        ),
        SpecRow(
          label: 'Sump Depth (in)',
          child: DenseField(
            key: const Key('field-sump'),
            value: design.sumpDepthIn.toStringAsFixed(1),
            numeric: true,
            onChanged: (v) {
              final parsed = parseNum(v);
              if (parsed != null) design.sumpDepthIn = parsed;
            },
          ),
        ),
      ],
    );
  }
}

class _TopAndCastingsPanel extends StatelessWidget {
  const _TopAndCastingsPanel();

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    final gradeRingItems = design.stack.items
        .where((i) => i.piece.type == PieceType.gradeRing)
        .toList();
    final gradeRings = gradeRingItems.fold<int>(0, (sum, i) => sum + i.count);
    final gradeRingHeight = gradeRingItems.fold<double>(
      0,
      (sum, i) => sum + i.piece.heightIn * i.count,
    );

    return SpecPanel(
      title: 'Top, Castings & Steps',
      children: [
        SpecRow(
          label: 'Top Type',
          child: DenseDropdown<bool>(
            key: const Key('field-top-type'),
            value: design.conicalTop,
            items: const [true, false],
            labelOf: (v) => v ? 'Conical (eccentric) top' : 'Flat top slab',
            onChanged: (v) => design.conicalTop = v,
          ),
        ),
        SpecRow(
          label: 'Max Grade Ring Stack (in)',
          child: DenseField(
            key: const Key('field-grade-ring-max'),
            value: design.maxGradeRingStackIn.toStringAsFixed(0),
            numeric: true,
            onChanged: (v) {
              final parsed = parseNum(v);
              if (parsed != null) design.maxGradeRingStackIn = parsed;
            },
          ),
        ),
        SpecRow(
          label: 'Grade Rings Used',
          child: Text(
            '$gradeRings ring(s) - ${gradeRingHeight.toStringAsFixed(0)}"',
            style: Mh.cellNum,
          ),
        ),
        SpecRow(
          label: 'EJ Casting',
          child: DenseDropdown<String>(
            key: const Key('field-casting'),
            value: design.castingId,
            items: kEjCastings.map((c) => c.id).toList(),
            labelOf: (id) => castingById(id).label,
            onChanged: (id) => design.castingId = id,
          ),
        ),
        SpecRow(
          label: 'Casting Weight / Opening',
          child: Text(
            '${design.casting.weightLbs.toStringAsFixed(0)} lb  -  '
            '${design.casting.clearOpeningIn.toStringAsFixed(0)}" clear opening',
            style: Mh.cellNum,
          ),
        ),
        SpecRow(
          label: 'Steps',
          child: DenseField(
            key: const Key('field-steps'),
            value: '${design.stepCount}',
            numeric: true,
            onChanged: (v) {
              final parsed = parseNum(v);
              if (parsed != null) design.stepCount = parsed.round();
            },
          ),
        ),
        SpecRow(
          label: 'Default Boot',
          child: DenseDropdown<BootType>(
            key: const Key('field-default-boot'),
            value: design.defaultBoot,
            items: BootType.values,
            labelOf: (b) => 'Set all: ${b.label}',
            onChanged: (b) => design.defaultBoot = b,
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

/// The openings grid: one row per penetration, every cell tab-reachable,
/// plus the seal schedule and the spatial checks it feeds.
class _OpeningsPanel extends StatelessWidget {
  const _OpeningsPanel();

  static const List<(String, int)> columns = [
    ('Pipe', 3),
    ('Type', 2),
    ('Product', 5),
    ('Nom in', 2),
    ('O.D. in', 2),
    ('Hole in', 2),
    ('Invert ft', 3),
    ('A-Clock deg', 3),
    ('Clock', 2),
    ('Boot', 4),
    ('Connector', 5),
    ('Hole X/Y in', 4),
    ('Wall / cut in', 4),
    ('', 2),
  ];

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    final validation = design.validation;
    final radiusIn = design.layout.outsideDiameterIn / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionBar(
          title: 'Openings & Pipe Schedule (${design.pipes.length})',
          trailing: TextButton(
            key: const Key('btn-add-pipe'),
            onPressed: design.addPipe,
            child: const Text('+ ADD OPENING', style: TextStyle(color: Colors.white)),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 640;
            final rows = <Widget>[
              if (!narrow) const GridHeaderRow(columns: columns),
              for (var i = 0; i < design.pipes.length; i++)
                _PipeRow(index: i, narrow: narrow, radiusIn: radiusIn, columns: columns),
            ];
            if (design.pipes.isEmpty) {
              rows.add(
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No openings yet - use + ADD OPENING.', style: Mh.label),
                ),
              );
            }
            if (narrow) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
            }
            return DenseGrid(minWidth: 1320, rows: rows);
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
                    Text(design.pipes[i].sealSpec, key: Key('seal-spec-$i'), style: Mh.cell),
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
                  Text('• ${c.message}', style: const TextStyle(color: Mh.danger, fontSize: 11.5)),
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
        key: Key('pipe-$index-material'),
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
      DenseDropdown<BootType>(
        key: Key('pipe-$index-boot'),
        value: pipe.boot,
        items: BootType.values,
        labelOf: (b) => b.label,
        onChanged: (b) => design.updatePipe(index, (p) => p.boot = b),
      ),
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
      Text(key: Key('pipe-$index-cut'), _cutText(design.size, pipe), style: Mh.cellNum),
      IconButton(
        key: Key('pipe-$index-delete'),
        icon: const Icon(Icons.delete_outline, size: 16),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 22),
        visualDensity: VisualDensity.compact,
        tooltip: 'Delete opening',
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
          cells: [(cells[0], 3), (cells[1], 3), (cells[4], 3), (cells[5], 3), (cells[13], 2)],
        ),
        const GridHeaderRow(
          columns: [('Invert', 3), ('A-Clock', 3), ('Hole X/Y', 4), ('Wall / cut', 4)],
        ),
        GridRow(
          highlight: highlight,
          cells: [(cells[6], 3), (cells[7], 3), (cells[11], 4), (cells[12], 4)],
        ),
        const GridHeaderRow(columns: [('Product', 4), ('Nom', 2), ('Boot', 4), ('Connector', 4)]),
        GridRow(
          highlight: highlight,
          cells: [(cells[2], 4), (cells[3], 2), (cells[9], 4), (cells[10], 4)],
        ),
        const SizedBox(height: Mh.gap),
      ],
    );
  }
}

class _BuildUpPanel extends StatelessWidget {
  const _BuildUpPanel();

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    final stack = design.stack;

    return SpecPanel(
      title: 'Computed Build-Up',
      children: [
        SpecRow(
          label: 'Structural Depth',
          child: Text(
            '${stack.structuralDepthIn.toStringAsFixed(2)}"  '
            '(rim - invert + sump - ${design.baseFloorThicknessIn.toStringAsFixed(0)}" floor)',
          ),
        ),
        if (stack.items.isNotEmpty)
          SpecRow(
            label: 'Base Section',
            child: Text(
              '${stack.items.first.piece.heightIn.toStringAsFixed(1)}" high, '
              '${stack.items.first.piece.weightLbs.toStringAsFixed(0)} lb'
              '${design.sumpDepthIn > 0.01 ? ' (incl. ${design.sumpDepthIn.toStringAsFixed(0)}" sump)' : ''}',
              style: Mh.cellNum,
            ),
          ),
        SpecRow(
          label: 'Stack Height',
          child: Text('${stack.achievedHeightIn.toStringAsFixed(2)}"'),
        ),
        SpecRow(
          label: 'Pieces / Joints',
          child: Text('${stack.totalPieceCount} pieces, ${stack.jointCount} joints'),
        ),
        SpecRow(
          label: 'Fit',
          child: stack.isExact
              ? const StatusChip(label: 'Exact to rim', color: Mh.ok, dense: false)
              : StatusChip(
                  label: '${stack.residualIn.toStringAsFixed(2)}" adjustment',
                  color: Mh.warn,
                  dense: false,
                ),
        ),
        for (final message in stack.messages)
          SpecRow(
            label: 'Note',
            child: Text(message, style: const TextStyle(fontSize: 12, color: Mh.warn)),
          ),
      ],
    );
  }
}
