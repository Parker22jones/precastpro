import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../export/bill_of_materials.dart';
import '../logic/pipe_validator.dart';
import '../models/precast_piece.dart';
import '../state/design_state.dart';

/// Left hand (or "Inputs" tab) column: job data, structure data, pipes, BOM.
class InputsPanel extends StatelessWidget {
  const InputsPanel({super.key, required this.design});

  final DesignState design;

  @override
  Widget build(BuildContext context) {
    final stack = design.stack;
    final bom = buildBillOfMaterials(stack);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Job Information',
          icon: Icons.assignment_outlined,
          child: TextFormField(
            key: const Key('field-job-name'),
            initialValue: design.jobName,
            decoration: const InputDecoration(labelText: 'Job Name', border: OutlineInputBorder()),
            onChanged: (v) => design.jobName = v,
          ),
        ),
        _Section(
          title: 'Structure',
          icon: Icons.architecture_outlined,
          child: Column(
            children: [
              _ResponsiveRow(
                children: [
                  _NumberField(
                    key: const Key('field-rim'),
                    label: 'Rim Elevation (ft)',
                    value: design.rimElevationFt,
                    onChanged: (v) => design.rimElevationFt = v,
                  ),
                  _NumberField(
                    key: const Key('field-invert'),
                    label: 'Invert Elevation (ft)',
                    value: design.invertElevationFt,
                    onChanged: (v) => design.invertElevationFt = v,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveRow(
                children: [
                  DropdownButtonFormField<double>(
                    key: const Key('field-diameter'),
                    isExpanded: true,
                    initialValue: design.structureDiameterIn,
                    decoration: const InputDecoration(
                        labelText: 'Structure Size', border: OutlineInputBorder()),
                    items: [
                      for (final d in PieceCatalog.availableDiameters)
                        DropdownMenuItem(value: d, child: Text('${d.toStringAsFixed(0)}" I.D.')),
                    ],
                    onChanged: (v) => v == null ? null : design.structureDiameterIn = v,
                  ),
                  DropdownButtonFormField<bool>(
                    key: const Key('field-top'),
                    isExpanded: true,
                    initialValue: design.conicalTop,
                    decoration:
                        const InputDecoration(labelText: 'Top Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Conical Top')),
                      DropdownMenuItem(value: false, child: Text('Flat Top')),
                    ],
                    onChanged: (v) => v == null ? null : design.conicalTop = v,
                  ),
                ],
              ),
            ],
          ),
        ),
        _Section(
          title: 'Pipe Penetrations',
          icon: Icons.adjust_outlined,
          trailing: FilledButton.tonalIcon(
            key: const Key('button-add-pipe'),
            onPressed: design.addPipe,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Pipe'),
          ),
          child: Column(
            children: [
              for (var i = 0; i < design.pipes.length; i++)
                _PipeCard(
                  key: ValueKey('pipe-$i'),
                  design: design,
                  index: i,
                  flagged: design.conflictedPipeNames.contains(design.pipes[i].name),
                ),
              if (design.pipes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No penetrations added yet.'),
                ),
            ],
          ),
        ),
        _Section(
          title: 'Calculated Stack',
          icon: Icons.layers_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow(
                label: 'Structural depth (rim - invert - 8" floor)',
                value: '${stack.structuralDepthIn.toStringAsFixed(2)}"',
              ),
              _StatRow(label: 'Stack height', value: '${stack.achievedHeightIn.toStringAsFixed(2)}"'),
              _StatRow(label: 'Pieces / horizontal joints', value: '${stack.totalPieceCount} / ${stack.jointCount}'),
              _StatRow(
                key: const Key('stat-total-weight'),
                label: 'Total combined weight',
                value: '${stack.totalWeightLbs.toStringAsFixed(0)} lb',
              ),
              _StatRow(
                label: 'Fit to rim',
                value: stack.isExact ? 'Exact' : '${stack.residualIn.toStringAsFixed(2)}" off',
                emphasize: !stack.isExact,
              ),
              const SizedBox(height: 10),
              Table(
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                columnWidths: const {
                  0: FlexColumnWidth(1.1),
                  1: FlexColumnWidth(3.4),
                  2: FlexColumnWidth(0.8),
                  3: FlexColumnWidth(1.6),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    children: const [
                      _Cell('MARK', bold: true),
                      _Cell('DESCRIPTION', bold: true),
                      _Cell('QTY', bold: true),
                      _Cell('WT (LB)', bold: true),
                    ],
                  ),
                  for (final line in bom)
                    TableRow(children: [
                      _Cell(line.mark),
                      _Cell(line.description),
                      _Cell('${line.count}'),
                      _Cell(line.totalWeightLbs.toStringAsFixed(0)),
                    ]),
                ],
              ),
              for (final m in stack.messages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(m, style: const TextStyle(color: Color(0xFFB26500), fontSize: 12)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PipeCard extends StatelessWidget {
  const _PipeCard({super.key, required this.design, required this.index, required this.flagged});

  final DesignState design;
  final int index;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final pipe = design.pipes[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: flagged ? const Color(0xFFFFEBEE) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: flagged ? const Color(0xFFD50000) : Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(pipe.name.isEmpty ? 'Unnamed pipe' : pipe.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text('@ ${pipe.clockPosition}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            IconButton(
              tooltip: 'Remove pipe',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => design.removePipeAt(index),
            ),
          ]),
          _ResponsiveRow(
            breakpoint: 420,
            children: [
              TextFormField(
                initialValue: pipe.name,
                decoration: const InputDecoration(labelText: 'Pipe Name', isDense: true),
                onChanged: (v) => design.updatePipe(index, (p) => p.name = v),
              ),
              _NumberField(
                label: 'O.D. (in)',
                value: pipe.outsideDiameterIn,
                dense: true,
                onChanged: (v) => design.updatePipe(index, (p) => p.outsideDiameterIn = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ResponsiveRow(
            breakpoint: 420,
            children: [
              _NumberField(
                label: 'Invert Elev. (ft)',
                value: pipe.invertElevationFt,
                dense: true,
                onChanged: (v) => design.updatePipe(index, (p) => p.invertElevationFt = v),
              ),
              _NumberField(
                label: 'Angle CW (0-360°)',
                value: pipe.horizontalAngleDeg,
                dense: true,
                onChanged: (v) => design.updatePipe(index, (p) => p.horizontalAngleDeg = v),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Bright, always-visible banner for spatial validation problems.
class ValidationBanner extends StatelessWidget {
  const ValidationBanner({super.key, required this.report});

  final ValidationReport report;

  @override
  Widget build(BuildContext context) {
    if (report.isClear) {
      return Container(
        key: const Key('validation-ok'),
        width: double.infinity,
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(children: [
          Icon(Icons.verified_outlined, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('SPATIAL CHECK PASSED — all penetrations clear by the 6" minimum.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      );
    }

    final critical = report.hasCritical;
    return Container(
      key: const Key('validation-warning'),
      width: double.infinity,
      color: critical ? const Color(0xFFD50000) : const Color(0xFFF9A825),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(critical ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
                color: critical ? Colors.white : Colors.black87, size: 20),
            const SizedBox(width: 8),
            Text(
              critical ? 'MANUFACTURING CONFLICT DETECTED' : 'PENETRATION CLEARANCE WARNING',
              style: TextStyle(
                color: critical ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          for (final c in report.conflicts)
            Text('• ${c.message}',
                style: TextStyle(color: critical ? Colors.white : Colors.black87, fontSize: 12)),
          for (final n in report.notices)
            Text('• $n',
                style: TextStyle(color: critical ? Colors.white : Colors.black87, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Lays its children out side by side when there is room, stacked otherwise,
/// so the same panel works on a Windows monitor and on an iPhone.
class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children, this.breakpoint = 520});

  static const double gap = 12;

  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child, this.trailing});

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            ),
            if (trailing != null) trailing!,
          ]),
          const Divider(height: 18),
          child,
        ]),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({super.key, required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: emphasize ? const Color(0xFFD50000) : null,
            )),
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(text,
            style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool dense;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(v.abs() < 1000 ? 1 : 0) : v.toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: widget.dense,
        border: widget.dense ? null : const OutlineInputBorder(),
      ),
      onChanged: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}
