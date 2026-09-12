import 'package:flutter/foundation.dart';

import '../logic/pipe_validator.dart';
import '../logic/stack_calculator.dart';
import '../logic/structure_layout.dart';
import '../models/casting_catalog.dart';
import '../models/component_status.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import '../models/pipe_product.dart';
import '../models/precast_piece.dart';
import '../models/structure_size.dart';

/// Everything the engineering wizard collects for a single structure, plus the
/// derived stack, layout and spatial validation.
class DesignState extends ChangeNotifier {
  DesignState({
    this.jobId = 'job-1',
    String jobName = 'Sample Job - MH-1',
    String structureMark = 'MH-1',
    String customer = 'City of Springfield',
    String? downstreamMark,
    String castingId = 'EJ BJWSA',
    int priority = 0,
    StructureType structureType = StructureType.sanitaryManhole,
    DateTime? castDate,
    double rimElevationFt = 100.0,
    double invertElevationFt = 88.5,
    double sumpDepthIn = 0,
    double structureDiameterIn = 48,
    StructureShape structureShape = StructureShape.round,
    double? insideWidthIn,
    double? insideLengthIn,
    double boxWallThicknessIn = kBoxWallThicknessIn,
    double baseFloorThicknessIn = kBaseFloorThicknessIn,
    bool conicalTop = true,
    BootType defaultBoot = BootType.aLok,
    double maxGradeRingStackIn = 12.0,
    int stepCount = 6,
    List<PipePenetration>? pipes,
  }) : _jobName = jobName,
       _structureMark = structureMark,
       _customer = customer,
       _downstreamMark = downstreamMark,
       _castingId = castingId,
       _priority = priority,
       _structureType = structureType,
       _castDate = castDate ?? DateTime(2026, 1, 15),
       _rimElevationFt = rimElevationFt,
       _invertElevationFt = invertElevationFt,
       _sumpDepthIn = sumpDepthIn,
       _structureDiameterIn = structureDiameterIn,
       _structureShape = structureShape,
       _insideWidthIn = insideWidthIn ?? 48,
       _insideLengthIn = insideLengthIn ?? 60,
       _boxWallThicknessIn = boxWallThicknessIn,
       _baseFloorThicknessIn = baseFloorThicknessIn,
       _conicalTop = conicalTop,
       _defaultBoot = defaultBoot,
       _maxGradeRingStackIn = maxGradeRingStackIn,
       _stepCount = stepCount,
       _pipes =
           pipes ??
           [
             PipePenetration(
               name: 'IN-A',
               outsideDiameterIn: 14.4,
               invertElevationFt: 89.0,
               horizontalAngleDeg: 0,
               material: PipeMaterial.pvc,
             ),
             PipePenetration(
               name: 'OUT',
               outsideDiameterIn: 18.0,
               invertElevationFt: 88.5,
               horizontalAngleDeg: 180,
               material: PipeMaterial.rcp,
             ),
           ];

  /// Job this structure belongs to in the global Jobs view.
  String jobId;

  String _jobName;
  String _structureMark;
  String _customer;
  String? _downstreamMark;
  String _castingId;
  int _priority;
  StructureType _structureType;
  DateTime _castDate;
  double _rimElevationFt;
  double _invertElevationFt;
  double _sumpDepthIn;
  double _structureDiameterIn;
  StructureShape _structureShape;
  double _insideWidthIn;
  double _insideLengthIn;
  double _boxWallThicknessIn;
  double _baseFloorThicknessIn;
  bool _conicalTop;
  BootType _defaultBoot;
  double _maxGradeRingStackIn;
  int _stepCount;
  final List<PipePenetration> _pipes;

  String get jobName => _jobName;
  String get structureMark => _structureMark;
  String get customer => _customer;
  StructureType get structureType => _structureType;
  DateTime get castDate => _castDate;
  double get rimElevationFt => _rimElevationFt;
  double get invertElevationFt => _invertElevationFt;
  double get sumpDepthIn => _sumpDepthIn;
  double get structureDiameterIn => _structureDiameterIn;
  StructureShape get structureShape => _structureShape;
  double get insideWidthIn => _insideWidthIn;
  double get insideLengthIn => _insideLengthIn;
  double get boxWallThicknessIn => _boxWallThicknessIn;
  double get baseFloorThicknessIn => _baseFloorThicknessIn;
  bool get conicalTop => _conicalTop;

  /// Plan geometry every engine measures from.
  StructureSize get size => _structureShape == StructureShape.round
      ? StructureSize.round(_structureDiameterIn)
      : StructureSize.rectangular(
          insideWidthIn: _insideWidthIn,
          insideLengthIn: _insideLengthIn,
          wallThicknessIn: _boxWallThicknessIn,
        );
  BootType get defaultBoot => _defaultBoot;
  double get maxGradeRingStackIn => _maxGradeRingStackIn;
  int get stepCount => _stepCount;
  List<PipePenetration> get pipes => List.unmodifiable(_pipes);

  /// Mark of the structure this one discharges into; null for an outfall.
  String? get downstreamMark => _downstreamMark;
  String get castingId => _castingId;
  EjCasting get casting => castingById(_castingId);

  /// Shop priority rank; lower sorts first, 0 means unranked.
  int get priority => _priority;

  set downstreamMark(String? value) {
    _downstreamMark = (value == null || value.trim().isEmpty) ? null : value.trim();
    notifyListeners();
  }

  set castingId(String value) {
    _castingId = value;
    notifyListeners();
  }

  set priority(int value) {
    _priority = value < 0 ? 0 : value;
    notifyListeners();
  }

  set jobName(String value) {
    _jobName = value;
    notifyListeners();
  }

  set structureMark(String value) {
    _structureMark = value;
    notifyListeners();
  }

  set customer(String value) {
    _customer = value;
    notifyListeners();
  }

  set structureType(StructureType value) {
    _structureType = value;
    notifyListeners();
  }

  set castDate(DateTime value) {
    _castDate = value;
    notifyListeners();
  }

  set rimElevationFt(double value) {
    _rimElevationFt = value;
    notifyListeners();
  }

  set invertElevationFt(double value) {
    _invertElevationFt = value;
    notifyListeners();
  }

  set sumpDepthIn(double value) {
    _sumpDepthIn = value;
    notifyListeners();
  }

  set structureDiameterIn(double value) {
    _structureDiameterIn = value;
    notifyListeners();
  }

  set structureShape(StructureShape value) {
    _structureShape = value;
    notifyListeners();
  }

  set insideWidthIn(double value) {
    _insideWidthIn = value <= 0 ? 12 : value;
    notifyListeners();
  }

  set insideLengthIn(double value) {
    _insideLengthIn = value <= 0 ? 12 : value;
    notifyListeners();
  }

  set boxWallThicknessIn(double value) {
    _boxWallThicknessIn = value <= 0 ? kBoxWallThicknessIn : value;
    notifyListeners();
  }

  set baseFloorThicknessIn(double value) {
    _baseFloorThicknessIn = value <= 0 ? kBaseFloorThicknessIn : value;
    notifyListeners();
  }

  set conicalTop(bool value) {
    _conicalTop = value;
    notifyListeners();
  }

  set defaultBoot(BootType value) {
    _defaultBoot = value;
    for (final pipe in _pipes) {
      pipe.boot = value;
    }
    notifyListeners();
  }

  set maxGradeRingStackIn(double value) {
    _maxGradeRingStackIn = value;
    notifyListeners();
  }

  set stepCount(int value) {
    _stepCount = value < 0 ? 0 : value;
    notifyListeners();
  }

  void addPipe([PipePenetration? pipe]) {
    _pipes.add(
      pipe ??
          PipePenetration(
            name: 'P-${_pipes.length + 1}',
            outsideDiameterIn: 12,
            invertElevationFt: _invertElevationFt,
            horizontalAngleDeg: 90,
            boot: _defaultBoot,
          ),
    );
    notifyListeners();
  }

  void removePipeAt(int index) {
    if (index < 0 || index >= _pipes.length) return;
    _pipes.removeAt(index);
    notifyListeners();
  }

  void updatePipe(int index, void Function(PipePenetration pipe) update) {
    if (index < 0 || index >= _pipes.length) return;
    update(_pipes[index]);
    notifyListeners();
  }

  StackResult get stack => const StackCalculator().calculate(
    rimElevationFt: _rimElevationFt,
    invertElevationFt: _invertElevationFt,
    size: size,
    conicalTop: _conicalTop,
    sumpDepthIn: _sumpDepthIn,
    maxGradeRingStackIn: _maxGradeRingStackIn,
    baseFloorThicknessIn: _baseFloorThicknessIn,
  );

  StructureLayout get layout => StructureLayout(
    stack: stack,
    rimElevationFt: _rimElevationFt,
    invertElevationFt: _invertElevationFt,
    size: size,
    sumpDepthIn: _sumpDepthIn,
    baseFloorThicknessIn: _baseFloorThicknessIn,
  );

  ValidationReport get validation => const PipeValidator().validate(
    pipes: _pipes,
    size: size,
    rimElevationFt: _rimElevationFt,
    invertElevationFt: _invertElevationFt,
    floorTopElevationFt: layout.floorTopElevationFt,
  );

  /// Names of pipes involved in at least one conflict.
  Set<String> get conflictedPipeNames => {
    for (final c in validation.conflicts) ...[c.pipeA, c.pipeB],
  };

  double get totalWeightLbs => stack.totalWeightLbs;

  /// True once any penetration uses a Press-Seal sleeve, which removes the
  /// mortar assumption from the schedule.
  bool get usesSleeves => _pipes.any((p) => p.psx.isSleeve);

  /// Total structural payload the yard loads out: concrete plus castings,
  /// boots and steps.
  double get payloadWeightLbs =>
      buildComponents().fold(0.0, (sum, c) => sum + c.weightLbs);

  /// Every physical item the yard has to produce or pull for this structure,
  /// in build order: concrete pieces, then castings and accessories.
  List<StructureComponent> buildComponents() {
    final out = <StructureComponent>[];
    var seq = 1;
    String nextId() => '$_structureMark-${(seq++).toString().padLeft(2, '0')}';

    for (final item in stack.items) {
      for (var i = 0; i < item.count; i++) {
        out.add(
          StructureComponent(
            id: nextId(),
            pieceId: item.piece.id,
            description: item.piece.description,
            weightLbs: item.piece.weightLbs,
            stockSku: _skuForPiece(item.piece),
          ),
        );
      }
    }
    final top = casting;
    out.add(
      StructureComponent(
        id: nextId(),
        pieceId: top.sku,
        description: top.label,
        weightLbs: top.weightLbs,
        stockSku: top.sku,
      ),
    );
    for (final pipe in _pipes) {
      final sleeveSku = pipe.psx.sku;
      out.add(
        StructureComponent(
          id: nextId(),
          pieceId: sleeveSku ?? pipe.boot.sku,
          description: sleeveSku == null
              ? '${pipe.boot.label} boot - ${pipe.name}'
              : '${pipe.psx.label} sleeve - ${pipe.name}',
          weightLbs: 12,
          stockSku: sleeveSku ?? pipe.boot.sku,
        ),
      );
    }
    for (var i = 0; i < _stepCount; i++) {
      out.add(
        StructureComponent(
          id: nextId(),
          pieceId: 'STEP-MA',
          description: 'Manhole step',
          weightLbs: 3,
          stockSku: 'STEP-MA',
        ),
      );
    }
    return out;
  }

  static String _skuForPiece(PrecastPiece piece) => switch (piece.type) {
    PieceType.riser when !piece.isRectangular =>
      'R${piece.insideDiameterIn.toStringAsFixed(0)}',
    PieceType.gradeRing => 'GR',
    _ => piece.id,
  };
}
