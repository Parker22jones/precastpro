import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../export/submittal_pdf.dart';
import '../painters/elevation_painter.dart';
import '../state/design_state.dart';
import 'drawings_panel.dart';
import 'inputs_panel.dart';

/// Width at or above which the desktop side-by-side layout is used.
const double kWideLayoutBreakpoint = 900;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.design});

  final DesignState design;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _exporting = false;

  Future<void> _exportSubmittal() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final design = widget.design;
      final elevationPng = await renderPainterToPng(
        buildElevationPainter(design),
        const Size(640, 900),
      );
      final planPng = await renderPainterToPng(
        buildPlanPainter(design),
        const Size(640, 640),
      );
      final bytes = await buildSubmittalPdf(
        SubmittalData(
          jobName: design.jobName,
          rimElevationFt: design.rimElevationFt,
          invertElevationFt: design.invertElevationFt,
          structureDiameterIn: design.structureDiameterIn,
          conicalTop: design.conicalTop,
          stack: design.stack,
          pipes: design.pipes,
          validation: design.validation,
          elevationPng: elevationPng,
          planPng: planPng,
          generatedAt: DateTime.now(),
        ),
      );
      final safeName = design.jobName.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim();
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
    return ListenableBuilder(
      listenable: widget.design,
      builder: (context, _) {
        final design = widget.design;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kWideLayoutBreakpoint;
            final body = Column(
              children: [
                ValidationBanner(report: design.validation),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: constraints.maxWidth * 0.42,
                              child: InputsPanel(design: design),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: DrawingsPanel(design: design)),
                          ],
                        )
                      : TabBarView(
                          children: [
                            InputsPanel(design: design),
                            DrawingsPanel(design: design, stacked: true),
                          ],
                        ),
                ),
              ],
            );

            final scaffold = Scaffold(
              appBar: AppBar(
                title: Text(design.jobName.isEmpty ? 'PrecastPro' : design.jobName),
                titleSpacing: 16,
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: FilledButton.icon(
                      key: const Key('button-export'),
                      onPressed: _exporting ? null : _exportSubmittal,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(wide ? 'Export Submittal' : 'Export'),
                    ),
                  ),
                ],
                bottom: wide
                    ? null
                    : const TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.tune), text: 'Inputs'),
                          Tab(icon: Icon(Icons.draw_outlined), text: 'Drawings'),
                        ],
                      ),
              ),
              body: SafeArea(child: body),
            );

            return wide ? scaffold : DefaultTabController(length: 2, child: scaffold);
          },
        );
      },
    );
  }
}

/// Exposed for tests: whether the desktop layout applies at [width].
bool isWideLayout(double width) => width >= kWideLayoutBreakpoint;

/// True on platforms where the submittal is shared rather than printed.
bool get isWebTarget => kIsWeb;
