import 'package:flutter/material.dart';

import '../painters/elevation_painter.dart';
import '../painters/plan_painter.dart';
import '../state/design_state.dart';

/// Right hand (or "Drawings" tab) column: elevation + plan canvases.
class DrawingsPanel extends StatelessWidget {
  const DrawingsPanel({super.key, required this.design, this.stacked = false});

  final DesignState design;

  /// Stack the two canvases vertically (narrow screens).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final elevation = _DrawingCard(
      title: 'Elevation View',
      child: CustomPaint(
        key: const Key('canvas-elevation'),
        painter: buildElevationPainter(design),
        child: const SizedBox.expand(),
      ),
    );
    final plan = _DrawingCard(
      title: 'Plan View',
      child: CustomPaint(
        key: const Key('canvas-plan'),
        painter: buildPlanPainter(design),
        child: const SizedBox.expand(),
      ),
    );

    if (stacked) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SizedBox(height: 460, child: elevation),
          const SizedBox(height: 12),
          SizedBox(height: 400, child: plan),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Expanded(flex: 3, child: elevation),
        const SizedBox(height: 12),
        Expanded(flex: 2, child: plan),
      ]),
    );
  }
}

ElevationPainter buildElevationPainter(DesignState design, {Color background = Colors.white}) =>
    ElevationPainter(
      layout: design.layout,
      pipes: design.pipes,
      conflictedPipes: design.conflictedPipeNames,
      background: background,
    );

PlanPainter buildPlanPainter(DesignState design, {Color background = Colors.white}) => PlanPainter(
      insideDiameterIn: design.structureDiameterIn,
      wallThicknessIn: design.layout.wallThicknessIn,
      pipes: design.pipes,
      conflictedPipes: design.conflictedPipeNames,
      background: background,
    );

class _DrawingCard extends StatelessWidget {
  const _DrawingCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.6)),
        ),
        Expanded(child: Container(color: Colors.white, child: child)),
      ]),
    );
  }
}
