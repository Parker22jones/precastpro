import 'package:flutter/material.dart';

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
              label: 'Inside Diameter',
              child: DenseDropdown<double>(
                value: design.structureDiameterIn,
                items: const [48, 60],
                labelOf: (d) => '${d.toStringAsFixed(0)}" I.D.',
                onChanged: (d) => design.structureDiameterIn = d,
              ),
            ),
            SpecRow(
              label: 'Wall Thickness',
              child: Text(
                '${design.layout.wallThicknessIn.toStringAsFixed(0)}"',
                style: Mh.cellNum,
              ),
            ),
            SpecRow(
              label: 'Outside Diameter',
              child: Text(
                '${design.layout.outsideDiameterIn.toStringAsFixed(0)}"',
                style: Mh.cellNum,
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
                '(rim - invert + sump - 8" floor)',
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
