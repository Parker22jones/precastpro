import 'package:flutter/material.dart';

import '../../models/structure_size.dart';
import '../app_scope.dart';
import '../mh_theme.dart';
import '../widgets/dense.dart';

/// Phase 2 - Elevations & Sizing.
class PhaseElevations extends StatelessWidget {
  const PhaseElevations({super.key});

  @override
  Widget build(BuildContext context) {
    final design = AppScope.of(context).design;
    final stack = design.stack;

    return ListView(
      padding: const EdgeInsets.all(Mh.gap),
      children: [
        SpecPanel(
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
        ),
        SpecPanel(
          title: 'Sizing',
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
                  numeric: true,
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
                  numeric: true,
                  onChanged: (v) {
                    final parsed = parseFeetInches(v);
                    if (parsed != null) design.insideLengthIn = parsed;
                  },
                ),
              ),
            ],
            SpecRow(
              label: 'Wall Thickness',
              child: Text(
                '${design.layout.wallThicknessIn.toStringAsFixed(0)}"',
                style: Mh.cellNum,
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
        ),
        SpecPanel(
          title: 'Computed Build-Up',
          children: [
            SpecRow(
              label: 'Structural Depth',
              child: Text(
                '${stack.structuralDepthIn.toStringAsFixed(2)}"  '
                '(rim - invert + sump - ${design.baseFloorThicknessIn.toStringAsFixed(0)}" floor)',
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
        ),
      ],
    );
  }
}
