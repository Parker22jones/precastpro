import 'package:flutter/material.dart';

import '../painters/cad_palette.dart';
import '../painters/elevation_painter.dart';
import '../painters/plan_painter.dart';
import '../state/design_state.dart';
import 'mh_theme.dart';

/// CAD sheet: elevation over plan, in either blueprint palette.
class DrawingsPanel extends StatefulWidget {
  const DrawingsPanel({super.key, required this.design, this.stacked = false});

  final DesignState design;

  /// Stack the two canvases vertically (narrow screens).
  final bool stacked;

  @override
  State<DrawingsPanel> createState() => _DrawingsPanelState();
}

class _DrawingsPanelState extends State<DrawingsPanel> {
  bool _slate = false;

  @override
  Widget build(BuildContext context) {
    final palette = _slate ? CadPalette.slate : CadPalette.light;
    final elevation = _Sheet(
      palette: palette,
      sheetSize: kElevationSheet,
      child: CustomPaint(
        key: const Key('canvas-elevation'),
        painter: buildElevationPainter(widget.design, palette: palette),
        child: const SizedBox.expand(),
      ),
    );
    final plan = _Sheet(
      palette: palette,
      sheetSize: kPlanSheet,
      child: CustomPaint(
        key: const Key('canvas-plan'),
        painter: buildPlanPainter(widget.design, palette: palette),
        child: const SizedBox.expand(),
      ),
    );

    final toggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('SLATE', style: Mh.sectionTitle),
        const SizedBox(width: 4),
        SizedBox(
          height: 18,
          child: Switch(
            key: const Key('toggle-slate'),
            value: _slate,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => setState(() => _slate = v),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: Mh.headerHeight,
          color: Mh.chrome,
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: Row(
            children: [
              const Expanded(child: Text('CAD DRAWING SHEET', style: Mh.sectionTitle)),
              toggle,
            ],
          ),
        ),
        Expanded(
          child: widget.stacked
              ? ListView(
                  padding: const EdgeInsets.all(4),
                  children: [elevation, const SizedBox(height: 4), plan],
                )
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Expanded(flex: 3, child: elevation),
                      const SizedBox(height: 4),
                      Expanded(flex: 2, child: plan),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

ElevationPainter buildElevationPainter(
  DesignState design, {
  CadPalette palette = CadPalette.light,
}) => ElevationPainter(
  layout: design.layout,
  pipes: design.pipes,
  conflictedPipes: design.conflictedPipeNames,
  palette: palette,
  title: 'ELEVATION (VIEW A-A) - ${design.structureMark}',
  castingLabel: design.casting.label,
  castingClearOpeningIn: design.casting.clearOpeningIn,
);

PlanPainter buildPlanPainter(DesignState design, {CadPalette palette = CadPalette.light}) =>
    PlanPainter(
      insideDiameterIn: design.structureDiameterIn,
      wallThicknessIn: design.layout.wallThicknessIn,
      pipes: design.pipes,
      conflictedPipes: design.conflictedPipeNames,
      topOpeningDiameterIn: design.casting.clearOpeningIn,
      palette: palette,
      title: 'PLAN VIEW - ${design.structureMark}',
    );

/// Logical drawing-sheet sizes. The painters are always laid out at these
/// sizes and scaled to fit, so annotations keep the same spacing on a phone,
/// on a monitor and in the exported PDF.
const Size kElevationSheet = Size(640, 900);
const Size kPlanSheet = Size(640, 640);

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, required this.palette, required this.sheetSize});

  final Widget child;
  final CadPalette palette;
  final Size sheetSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.paper,
        border: Border.all(color: Mh.gridLine),
      ),
      child: AspectRatio(
        aspectRatio: sheetSize.width / sheetSize.height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(width: sheetSize.width, height: sheetSize.height, child: child),
        ),
      ),
    );
  }
}
