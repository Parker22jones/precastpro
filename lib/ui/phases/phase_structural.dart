import 'package:flutter/material.dart';

import '../../models/casting_catalog.dart';
import '../../models/job_spec.dart';
import '../../models/pipe_product.dart';
import '../../models/precast_piece.dart';
import '../app_scope.dart';
import '../mh_theme.dart';
import '../widgets/dense.dart';

/// Phase 4 - Structural Details: top type, grade ring allowance, boots, steps.
class PhaseStructural extends StatelessWidget {
  const PhaseStructural({super.key});

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

    return ListView(
      padding: const EdgeInsets.all(Mh.gap),
      children: [
        SpecPanel(
          title: 'Top Section',
          children: [
            SpecRow(
              label: 'Top Type',
              child: DenseDropdown<bool>(
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
          ],
        ),
        SpecPanel(
          title: 'Boot / Connector Schedule',
          trailing: _DefaultBootPicker(),
          children: [
            DenseGrid(
              minWidth: 760,
              rows: [
                const GridHeaderRow(
                  columns: [
                    ('Pipe', 3),
                    ('O.D.', 2),
                    ('Hole', 2),
                    ('Boot Type', 5),
                    ('Press-Seal Lookup', 5),
                    ('Stock SKU', 3),
                  ],
                ),
                for (var i = 0; i < design.pipes.length; i++)
                  GridRow(
                    striped: i.isOdd,
                    cells: [
                      (Text(design.pipes[i].name, style: Mh.cell), 3),
                      (
                        Text(
                          '${design.pipes[i].outsideDiameterIn.toStringAsFixed(1)}"',
                          style: Mh.cellNum,
                        ),
                        2,
                      ),
                      (
                        Text(
                          '${design.pipes[i].holeSizeIn.toStringAsFixed(1)}"',
                          style: Mh.cellNum,
                        ),
                        2,
                      ),
                      (
                        DenseDropdown<BootType>(
                          value: design.pipes[i].boot,
                          items: BootType.values,
                          labelOf: (b) => b.label,
                          onChanged: (b) => design.updatePipe(i, (p) => p.boot = b),
                        ),
                        5,
                      ),
                      (
                        DenseDropdown<PsxConnector>(
                          key: Key('structural-psx-$i'),
                          value: design.pipes[i].psx,
                          items: PsxConnector.values,
                          labelOf: (c) => c.label,
                          onChanged: (c) => design.updatePipe(i, (p) => p.applyPsx(c)),
                        ),
                        5,
                      ),
                      (
                        Text(
                          design.pipes[i].psx.sku ?? design.pipes[i].boot.sku,
                          style: Mh.cell,
                        ),
                        3,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DefaultBootPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    return SizedBox(
      width: 180,
      child: DenseDropdown<BootType>(
        value: design.defaultBoot,
        items: BootType.values,
        labelOf: (b) => 'Set all: ${b.label}',
        onChanged: (b) => design.defaultBoot = b,
      ),
    );
  }
}
