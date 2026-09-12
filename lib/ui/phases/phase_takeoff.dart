import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../export/bill_of_materials.dart';
import '../../export/submittal_pdf.dart';
import '../../models/component_status.dart';
import '../../models/job_spec.dart';
import '../../painters/elevation_painter.dart';
import '../app_scope.dart';
import '../drawings_panel.dart';
import '../mh_theme.dart';
import '../status_colors.dart';
import '../widgets/dense.dart';

/// Phase 5 - Takeoff & Production Sheet.
class PhaseTakeoff extends StatefulWidget {
  const PhaseTakeoff({super.key});

  @override
  State<PhaseTakeoff> createState() => _PhaseTakeoffState();
}

class _PhaseTakeoffState extends State<PhaseTakeoff> {
  bool _exporting = false;

  Future<void> _exportSubmittal() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final app = AppScope.of(context);
    final design = app.design;
    final job = app.activeJob;
    try {
      final elevationPng = await renderPainterToPng(buildElevationPainter(design), kElevationSheet);
      final planPng = await renderPainterToPng(buildPlanPainter(design), kPlanSheet);
      final bytes = await buildSubmittalPdf(
        SubmittalData(
          jobName: design.jobName,
          jobNumber: job.number,
          contractor: job.contractor,
          structureMark: design.structureMark,
          downstreamMark: design.downstreamMark,
          customer: design.customer,
          structureTypeLabel: design.structureType.label,
          castDate: design.castDate,
          sumpDepthIn: design.sumpDepthIn,
          rimElevationFt: design.rimElevationFt,
          invertElevationFt: design.invertElevationFt,
          structureDiameterIn: design.structureDiameterIn,
          wallThicknessIn: design.layout.wallThicknessIn,
          castingLabel: design.casting.label,
          castingWeightLbs: design.casting.weightLbs,
          conicalTop: design.conicalTop,
          stack: design.stack,
          pipes: design.pipes,
          validation: design.validation,
          elevationPng: elevationPng,
          planPng: planPng,
          generatedAt: DateTime.now(),
        ),
      );
      final safeName = '${design.jobName} ${design.structureMark}'
          .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
          .trim();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${safeName.isEmpty ? 'PrecastPro' : safeName} Submittal.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final design = app.design;
    final record = app.activeStructure;
    final bom = buildBillOfMaterials(design.stack);
    final componentWeight = record.totalWeightLbs;

    return ListView(
      padding: const EdgeInsets.all(Mh.gap),
      children: [
        SpecPanel(
          title: 'Bill of Materials - Concrete',
          trailing: Text('${design.stack.totalPieceCount} PIECES', style: Mh.sectionTitle),
          children: [
            DenseGrid(
              minWidth: 640,
              rows: [
                const GridHeaderRow(
                  columns: [
                    ('Mark', 2),
                    ('Description', 6),
                    ('Qty', 1),
                    ('Height in', 2),
                    ('Unit lb', 2),
                    ('Total lb', 2),
                  ],
                ),
                for (var i = 0; i < bom.length; i++)
                  GridRow(
                    striped: i.isOdd,
                    cells: [
                      (Text(bom[i].mark, style: Mh.cell), 2),
                      (Text(bom[i].description, style: Mh.cell), 6),
                      (Text('${bom[i].count}', style: Mh.cellNum), 1),
                      (Text(bom[i].totalHeightIn.toStringAsFixed(0), style: Mh.cellNum), 2),
                      (Text(_lbs(bom[i].unitWeightLbs), style: Mh.cellNum), 2),
                      (Text(_lbs(bom[i].totalWeightLbs), style: Mh.cellNum), 2),
                    ],
                  ),
                GridRow(
                  highlight: Mh.headerFill,
                  cells: [
                    (const Text('', style: Mh.cell), 2),
                    (
                      const Text(
                        'TOTAL STRUCTURAL WEIGHT',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      6,
                    ),
                    (Text('${design.stack.totalPieceCount}', style: Mh.cellNum), 1),
                    (Text(design.stack.achievedHeightIn.toStringAsFixed(0), style: Mh.cellNum), 2),
                    (const Text('', style: Mh.cell), 2),
                    (
                      Text(
                        _lbs(design.totalWeightLbs),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      2,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SpecPanel(
          title: 'Production Sheet - Component Status',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ALL-IN ${_lbs(componentWeight)} LB', style: Mh.sectionTitle),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('btn-release-yard'),
                onPressed: app.releaseActiveStructureToYard,
                child: const Text('RE-ISSUE TO YARD', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          children: [
            DenseGrid(
              minWidth: 760,
              rows: [
                const GridHeaderRow(
                  columns: [
                    ('Tag', 2),
                    ('Component', 6),
                    ('SKU', 2),
                    ('Weight lb', 2),
                    ('Status', 3),
                    ('Advance', 3),
                  ],
                ),
                for (var i = 0; i < record.components.length; i++)
                  _ComponentRow(index: i, striped: i.isOdd),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Mh.gap),
          child: Row(
            children: [
              FilledButton.icon(
                key: const Key('button-export'),
                onPressed: _exporting ? null : _exportSubmittal,
                icon: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('EXPORT SUBMITTAL'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.index, required this.striped});

  final int index;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final record = app.activeStructure;
    final component = record.components[index];

    return GridRow(
      striped: striped,
      cells: [
        (Text(component.id, style: Mh.cell), 2),
        (Text(component.description, style: Mh.cell), 6),
        (Text(component.stockSku, style: Mh.cell), 2),
        (Text(_lbs(component.weightLbs), style: Mh.cellNum), 2),
        (
          StatusChip(
            label: component.status.label,
            color: statusColor(component.status),
            dense: false,
          ),
          3,
        ),
        (
          component.status.next == null
              ? const SizedBox.shrink()
              : TextButton(
                  key: Key('advance-$index'),
                  onPressed: () => app.advanceComponent(record, component),
                  child: Text(
                    component.status.next!.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          3,
        ),
      ],
    );
  }
}

String _lbs(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
