import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/pipe_validator.dart';
import '../logic/stack_calculator.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import 'bill_of_materials.dart';

class SubmittalData {
  const SubmittalData({
    required this.jobName,
    this.structureMark = '',
    this.customer = '',
    this.structureTypeLabel = '',
    this.castDate,
    this.sumpDepthIn = 0,
    required this.rimElevationFt,
    required this.invertElevationFt,
    required this.structureDiameterIn,
    required this.conicalTop,
    required this.stack,
    required this.pipes,
    required this.validation,
    required this.elevationPng,
    required this.planPng,
    required this.generatedAt,
  });

  final String jobName;
  final String structureMark;
  final String customer;
  final String structureTypeLabel;
  final DateTime? castDate;
  final double sumpDepthIn;
  final double rimElevationFt;
  final double invertElevationFt;
  final double structureDiameterIn;
  final bool conicalTop;
  final StackResult stack;
  final List<PipePenetration> pipes;
  final ValidationReport validation;
  final Uint8List elevationPng;
  final Uint8List planPng;
  final DateTime generatedAt;
}

/// Builds the dock drawing / shop submittal sheet.
Future<Uint8List> buildSubmittalPdf(SubmittalData data) async {
  final doc = pw.Document(title: '${data.jobName} - Precast Submittal', author: 'PrecastPro');
  final bom = buildBillOfMaterials(data.stack);
  final elevation = pw.MemoryImage(data.elevationPng);
  final plan = pw.MemoryImage(data.planPng);

  const accent = PdfColor.fromInt(0xFF1B3A57);
  const light = PdfColor.fromInt(0xFFEEF2F6);

  pw.Widget cell(String text, {bool bold = false, PdfColor color = PdfColors.black}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget infoRow(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 96,
            child: pw.Text(k, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey700)),
          ),
          pw.Text(v, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Title block.
          pw.Container(
            color: accent,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('PRECAST MANHOLE SUBMITTAL',
                      style: pw.TextStyle(
                          fontSize: 15, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  pw.Text(data.jobName,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFFBBD3E8))),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('PrecastPro',
                      style: pw.TextStyle(
                          fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatDate(data.generatedAt),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFFBBD3E8))),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Drawings.
                pw.Expanded(
                  flex: 3,
                  child: pw.Row(children: [
                    pw.Expanded(
                      child: pw.Container(
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey400)),
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(elevation, fit: pw.BoxFit.contain),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Container(
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey400)),
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(plan, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ]),
                ),
                pw.SizedBox(width: 10),
                // Data column.
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                    _sectionTitle('STRUCTURE DATA', accent),
                    pw.SizedBox(height: 4),
                    infoRow('Job / Structure',
                        [data.jobName, if (data.structureMark.isNotEmpty) data.structureMark]
                            .join(' / ')),
                    if (data.customer.isNotEmpty) infoRow('Customer', data.customer),
                    if (data.structureTypeLabel.isNotEmpty)
                      infoRow('Structure Type', data.structureTypeLabel),
                    if (data.castDate != null) infoRow('Cast Date', _formatDate(data.castDate!)),
                    infoRow('Structure Size', '${data.structureDiameterIn.toStringAsFixed(0)}" I.D.'),
                    infoRow('Top Type', data.conicalTop ? 'Conical (eccentric)' : 'Flat top slab'),
                    infoRow('Rim Elevation', "${data.rimElevationFt.toStringAsFixed(2)}'"),
                    infoRow('Invert Elevation', "${data.invertElevationFt.toStringAsFixed(2)}'"),
                    if (data.sumpDepthIn > 0)
                      infoRow('Sump Depth', '${data.sumpDepthIn.toStringAsFixed(1)}" below invert'),
                    infoRow('Structural Depth',
                        '${data.stack.structuralDepthIn.toStringAsFixed(2)}" (rim - invert - 8" floor)'),
                    infoRow('Stack Height', '${data.stack.achievedHeightIn.toStringAsFixed(2)}"'),
                    infoRow('Horizontal Joints', '${data.stack.jointCount}'),
                    infoRow('Fit', data.stack.isExact
                        ? 'Exact to rim'
                        : '${data.stack.residualIn.toStringAsFixed(2)}" adjustment required'),
                    pw.SizedBox(height: 8),
                    _sectionTitle('BILL OF MATERIALS', accent),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.2),
                        1: pw.FlexColumnWidth(4),
                        2: pw.FlexColumnWidth(1),
                        3: pw.FlexColumnWidth(1.6),
                        4: pw.FlexColumnWidth(1.8),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: light),
                          children: [
                            cell('MARK', bold: true),
                            cell('DESCRIPTION', bold: true),
                            cell('QTY', bold: true),
                            cell('UNIT WT (LB)', bold: true),
                            cell('TOTAL WT (LB)', bold: true),
                          ],
                        ),
                        for (final line in bom)
                          pw.TableRow(children: [
                            cell(line.mark),
                            cell(line.description),
                            cell('${line.count}'),
                            cell(_lbs(line.unitWeightLbs)),
                            cell(_lbs(line.totalWeightLbs)),
                          ]),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: light),
                          children: [
                            cell(''),
                            cell('TOTAL COMBINED MANHOLE WEIGHT', bold: true),
                            cell('${data.stack.totalPieceCount}', bold: true),
                            cell(''),
                            cell(_lbs(data.stack.totalWeightLbs), bold: true),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    _sectionTitle('PIPE PENETRATION SCHEDULE', accent),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: light),
                          children: [
                            cell('PIPE', bold: true),
                            cell('TYPE', bold: true),
                            cell('O.D.', bold: true),
                            cell('HOLE', bold: true),
                            cell('INVERT', bold: true),
                            cell('ANGLE CW', bold: true),
                            cell('CLOCK', bold: true),
                            cell('BOOT', bold: true),
                          ],
                        ),
                        for (final p in data.pipes)
                          pw.TableRow(children: [
                            cell(p.name),
                            cell(p.material.label),
                            cell('${p.outsideDiameterIn.toStringAsFixed(1)}"'),
                            cell('${p.holeSizeIn.toStringAsFixed(1)}"'),
                            cell("${p.invertElevationFt.toStringAsFixed(2)}'"),
                            cell('${p.normalizedAngleDeg.toStringAsFixed(0)} deg'),
                            cell(p.clockPosition),
                            cell(p.boot.label),
                          ]),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    if (data.validation.conflicts.isNotEmpty || data.validation.notices.isNotEmpty)
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFFFEBEE),
                          border: pw.Border.all(color: PdfColors.red700),
                        ),
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text('REVIEW REQUIRED - SPATIAL CHECK',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                          for (final c in data.validation.conflicts)
                            pw.Text('- ${c.message}',
                                style: const pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
                          for (final n in data.validation.notices)
                            pw.Text('- $n',
                                style: const pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
                        ]),
                      )
                    else
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFE8F5E9),
                          border: pw.Border.all(color: PdfColors.green700),
                        ),
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'SPATIAL CHECK PASSED - all penetrations clear by 6" minimum.',
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                        ),
                      ),
                    for (final m in data.stack.messages)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text('NOTE: $m',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange900)),
                      ),
                  ]),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey400))),
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Generated by PrecastPro - verify all field dimensions prior to casting.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
              pw.Text('TOTAL WEIGHT: ${_lbs(data.stack.totalWeightLbs)} LB',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

pw.Widget _sectionTitle(String text, PdfColor color) => pw.Container(
      width: double.infinity,
      color: color,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
    );

String _lbs(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
