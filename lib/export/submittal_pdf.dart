import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/pipe_validator.dart';
import '../logic/stack_calculator.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import '../models/pipe_product.dart';
import '../models/precast_piece.dart';
import '../models/structure_size.dart';
import 'bill_of_materials.dart';

/// Everything the Select Precast submittal package prints.
class SubmittalData {
  const SubmittalData({
    required this.jobName,
    this.jobNumber = '',
    this.contractor = '',
    this.structureMark = '',
    this.downstreamMark,
    this.customer = '',
    this.structureTypeLabel = '',
    this.castDate,
    this.sumpDepthIn = 0,
    required this.rimElevationFt,
    required this.invertElevationFt,
    required this.size,
    this.floorThicknessIn = kBaseFloorThicknessIn,
    this.castingLabel = '',
    this.castingWeightLbs = 0,
    required this.conicalTop,
    required this.stack,
    required this.pipes,
    required this.validation,
    required this.elevationPng,
    required this.planPng,
    required this.generatedAt,
  });

  final String jobName;
  final String jobNumber;
  final String contractor;
  final String structureMark;
  final String? downstreamMark;
  final String customer;
  final String structureTypeLabel;
  final DateTime? castDate;
  final double sumpDepthIn;
  final double rimElevationFt;
  final double invertElevationFt;
  /// Plan geometry of the structure: round diameter or box width x length.
  final StructureSize size;
  final double floorThicknessIn;
  final String castingLabel;
  final double castingWeightLbs;
  final bool conicalTop;
  final StackResult stack;
  final List<PipePenetration> pipes;
  final ValidationReport validation;
  final Uint8List elevationPng;
  final Uint8List planPng;
  final DateTime generatedAt;

  /// Top of the base floor slab: no opening may be built below it.
  double get floorTopElevationFt =>
      invertElevationFt - sumpDepthIn / 12.0 + floorThicknessIn / 12.0;

  /// Invert an opening is actually built at, held up out of the floor slab.
  double buildInvertElevationFt(PipePenetration pipe) =>
      pipe.invertElevationFt < floorTopElevationFt
      ? floorTopElevationFt
      : pipe.invertElevationFt;

  /// Top of casting = rim elevation (the casting sits on the grade rings).
  double get topOfCastingFt => rimElevationFt;

  /// Absolute raw payload for yard loading: concrete plus the iron casting.
  double get payloadWeightLbs => stack.totalWeightLbs + castingWeightLbs;

  /// Deterministic tracking number so a re-export of the same structure on the
  /// same day reproduces the same identifier.
  String get submittalNumber {
    final mark = structureMark.isEmpty ? 'STR' : structureMark;
    final job = jobNumber.isEmpty ? 'SP' : jobNumber;
    final d = generatedAt;
    return 'SP-$job-$mark-'
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }
}

const _accent = PdfColor.fromInt(0xFF1B3A57);
const _light = PdfColor.fromInt(0xFFEEF2F6);

/// Builds the multi-page Select Precast submittal package:
/// title sheet + calc block, CAD blueprint sheet, and takeoff/BOM sheet.
Future<Uint8List> buildSubmittalPdf(SubmittalData data) async {
  final doc = pw.Document(
    title: 'Select Precast Submittal - ${data.jobName} ${data.structureMark}',
    author: 'Select Precast, Inc.',
  );
  final bom = buildBillOfMaterials(data.stack);
  final elevation = pw.MemoryImage(data.elevationPng);
  final plan = pw.MemoryImage(data.planPng);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(30),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _titleBlock(data),
          pw.SizedBox(height: 12),
          _sectionTitle('SUBMITTAL TRACKING'),
          pw.SizedBox(height: 4),
          _kvTable([
            ('Submittal No.', data.submittalNumber),
            ('Issued', _formatDate(data.generatedAt)),
            ('Job Name', data.jobName),
            ('Job Number', data.jobNumber.isEmpty ? '-' : data.jobNumber),
            ('Contractor', data.contractor.isEmpty ? '-' : data.contractor),
            ('Customer', data.customer.isEmpty ? '-' : data.customer),
            ('Structure', data.structureMark.isEmpty ? '-' : data.structureMark),
            ('Structure Type', data.structureTypeLabel.isEmpty ? '-' : data.structureTypeLabel),
            ('Flows Into', data.downstreamMark ?? 'None (outfall)'),
            ('Scheduled Cast', data.castDate == null ? '-' : _formatDate(data.castDate!)),
            ('Revision', 'Rev 0 - issued for approval'),
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('CALCULATION BLOCK'),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _designBuildHeightTable(data)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _stackBuildHeightTable(data)),
            ],
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('PIPE PENETRATION SCHEDULE'),
          pw.SizedBox(height: 4),
          _pipeTable(data),
          pw.SizedBox(height: 8),
          _spatialBanner(data),
          pw.Spacer(),
          _bomFooter(data),
        ],
      ),
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(data, '2D CAD BLUEPRINTS - ELEVATION & PLAN'),
          pw.SizedBox(height: 8),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(child: _drawingFrame('ELEVATION VIEW', elevation)),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _drawingFrame('PLAN VIEW - 0 deg NORTH FIXED', plan)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Ring joints labeled on elevation. Plan view angles measured clockwise '
            'from the fixed 0 deg North indicator.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
          ),
          pw.SizedBox(height: 4),
          _bomFooter(data),
        ],
      ),
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(30),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(data, 'TAKEOFF & BILL OF MATERIALS'),
          pw.SizedBox(height: 8),
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
                decoration: const pw.BoxDecoration(color: _light),
                children: [
                  _cell('MARK', bold: true),
                  _cell('DESCRIPTION', bold: true),
                  _cell('QTY', bold: true),
                  _cell('UNIT WT (LB)', bold: true),
                  _cell('TOTAL WT (LB)', bold: true),
                ],
              ),
              for (final line in bom)
                pw.TableRow(
                  children: [
                    _cell(line.mark),
                    _cell(line.description),
                    _cell('${line.count}'),
                    _cell(_lbs(line.unitWeightLbs)),
                    _cell(_lbs(line.totalWeightLbs)),
                  ],
                ),
              if (data.castingLabel.isNotEmpty)
                pw.TableRow(
                  children: [
                    _cell('CASTING'),
                    _cell(data.castingLabel),
                    _cell('1'),
                    _cell(_lbs(data.castingWeightLbs)),
                    _cell(_lbs(data.castingWeightLbs)),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _light),
                children: [
                  _cell(''),
                  _cell('TOTAL COMBINED STRUCTURE WEIGHT', bold: true),
                  _cell('${data.stack.totalPieceCount}', bold: true),
                  _cell(''),
                  _cell(_lbs(data.payloadWeightLbs), bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _sectionTitle('ANNULAR SPACE / CONNECTOR SCHEDULE'),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _light),
                children: [
                  _cell('PIPE', bold: true),
                  _cell('CONNECTOR', bold: true),
                  _cell('SEAL SPECIFICATION', bold: true),
                ],
              ),
              for (final p in data.pipes)
                pw.TableRow(
                  children: [
                    _cell(p.name),
                    _cell(p.psx.isSleeve ? p.psx.label : p.boot.label),
                    _cell(p.sealSpec),
                  ],
                ),
            ],
          ),
          for (final m in data.stack.messages)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'NOTE: $m',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange900),
              ),
            ),
          pw.Spacer(),
          _bomFooter(data),
        ],
      ),
    ),
  );

  return doc.save();
}

pw.Widget _titleBlock(SubmittalData data) => pw.Container(
  color: _accent,
  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'SELECT PRECAST, INC.',
        style: pw.TextStyle(fontSize: 26, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'PRECAST STRUCTURE SUBMITTAL PACKAGE',
        style: pw.TextStyle(
          fontSize: 12,
          color: const PdfColor.fromInt(0xFFBBD3E8),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        '${data.jobName}   |   ${data.structureMark}',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
      ),
    ],
  ),
);

pw.Widget _sheetHeader(SubmittalData data, String title) => pw.Container(
  color: _accent,
  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'SELECT PRECAST, INC. - $title',
        style: pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        '${data.submittalNumber}   ${data.structureMark}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFFBBD3E8)),
      ),
    ],
  ),
);

pw.Widget _drawingFrame(String caption, pw.MemoryImage image) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Container(
      color: _light,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(caption, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    ),
    pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey400)),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    ),
  ],
);

/// Design side of the calc block: the elevations the design must satisfy.
pw.Widget _designBuildHeightTable(SubmittalData data) {
  final designHeightIn =
      (data.topOfCastingFt - data.invertElevationFt) * 12.0 + data.sumpDepthIn;
  return _calcTable('DESIGN BUILD HEIGHT', [
    ('Top of Casting', "${data.topOfCastingFt.toStringAsFixed(2)}'"),
    ('Outlet Invert', "${data.invertElevationFt.toStringAsFixed(2)}'"),
    ('Sump Below Invert', '${data.sumpDepthIn.toStringAsFixed(2)}"'),
    ('Floor Thickness', '${data.floorThicknessIn.toStringAsFixed(2)}"'),
    ('Wall Thickness', '${data.size.wallThicknessIn.toStringAsFixed(2)}"'),
    ('Structure Shape', data.size.shape.label),
    ('Inside Size', data.size.sizeLabel),
    ('Gross Design Height', '${designHeightIn.toStringAsFixed(2)}"'),
    ('Required Build Height', '${data.stack.structuralDepthIn.toStringAsFixed(2)}"'),
  ]);
}

/// Stack side of the calc block: the segment-by-segment gains that get there.
pw.Widget _stackBuildHeightTable(SubmittalData data) {
  final rows = <(String, String)>[
    ('Base Floor', '${data.floorThicknessIn.toStringAsFixed(2)}"'),
    for (final item in data.stack.items)
      (
        '${item.count} x ${item.piece.description}',
        '${item.totalHeightIn.toStringAsFixed(2)}"',
      ),
    ('Stack Gain (total)', '${data.stack.achievedHeightIn.toStringAsFixed(2)}"'),
    ('Adjustment / Residual', '${data.stack.residualIn.toStringAsFixed(2)}"'),
    ('Horizontal Joints', '${data.stack.jointCount}'),
    (
      'Fit',
      data.stack.isExact ? 'EXACT TO RIM' : 'FIELD ADJUSTMENT REQUIRED',
    ),
  ];
  return _calcTable('STACK BUILD HEIGHT', rows);
}

pw.Widget _calcTable(String title, List<(String, String)> rows) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Container(
      color: _light,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ),
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
      children: [
        for (final row in rows)
          pw.TableRow(children: [_cell(row.$1), _cell(row.$2, bold: true)]),
      ],
    ),
  ],
);

pw.Widget _kvTable(List<(String, String)> rows) => pw.Table(
  border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
  columnWidths: const {
    0: pw.FlexColumnWidth(2),
    1: pw.FlexColumnWidth(3),
    2: pw.FlexColumnWidth(2),
    3: pw.FlexColumnWidth(3),
  },
  children: [
    for (var i = 0; i < rows.length; i += 2)
      pw.TableRow(
        children: [
          _cell(rows[i].$1, bold: true),
          _cell(rows[i].$2),
          _cell(i + 1 < rows.length ? rows[i + 1].$1 : '', bold: true),
          _cell(i + 1 < rows.length ? rows[i + 1].$2 : ''),
        ],
      ),
  ],
);

pw.Widget _pipeTable(SubmittalData data) => pw.Table(
  border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
  children: [
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _light),
      children: [
        _cell('PIPE', bold: true),
        _cell('PRODUCT', bold: true),
        _cell('O.D.', bold: true),
        _cell('HOLE', bold: true),
        _cell('INVERT', bold: true),
        _cell('ANGLE CW', bold: true),
        _cell('CLOCK', bold: true),
        _cell('CONNECTOR', bold: true),
      ],
    ),
    for (final p in data.pipes)
      pw.TableRow(
        children: [
          _cell(p.name),
          _cell(p.product?.label ?? p.material.label),
          _cell('${p.outsideDiameterIn.toStringAsFixed(1)}"'),
          _cell('${p.holeSizeIn.toStringAsFixed(1)}"'),
          _cell("${data.buildInvertElevationFt(p).toStringAsFixed(2)}'"),
          _cell('${p.normalizedAngleDeg.toStringAsFixed(0)} deg'),
          _cell(p.clockPosition),
          _cell(p.psx.isSleeve ? p.psx.label : p.boot.label),
        ],
      ),
  ],
);

pw.Widget _spatialBanner(SubmittalData data) {
  final hasIssues =
      data.validation.conflicts.isNotEmpty || data.validation.notices.isNotEmpty;
  if (!hasIssues) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFE8F5E9),
        border: pw.Border.all(color: PdfColors.green700),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        'SPATIAL CHECK PASSED - all penetrations clear by 6" minimum.',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green800,
        ),
      ),
    );
  }
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFFFEBEE),
      border: pw.Border.all(color: PdfColors.red700),
    ),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REVIEW REQUIRED - SPATIAL CHECK',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red800,
          ),
        ),
        for (final c in data.validation.conflicts)
          pw.Text('- ${c.message}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
        for (final n in data.validation.notices)
          pw.Text('- $n', style: const pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
      ],
    ),
  );
}

/// Yard loading targets repeated on every sheet.
pw.Widget _bomFooter(SubmittalData data) => pw.Container(
  decoration: const pw.BoxDecoration(
    color: _light,
    border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey400)),
  ),
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'YARD LOADING - ${data.stack.totalPieceCount} PIECES   |   '
        'CONCRETE ${_lbs(data.stack.totalWeightLbs)} LB   |   '
        'CASTING ${_lbs(data.castingWeightLbs)} LB',
        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey800),
      ),
      pw.Text(
        'RAW PAYLOAD TARGET: ${_lbs(data.payloadWeightLbs)} LB',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _cell(String text, {bool bold = false, PdfColor color = PdfColors.black}) => pw.Padding(
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

pw.Widget _sectionTitle(String text) => pw.Container(
  width: double.infinity,
  color: _accent,
  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
  ),
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
