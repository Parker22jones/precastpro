import 'package:flutter/foundation.dart';

import '../logic/pipe_validator.dart';
import '../logic/stack_calculator.dart';
import '../logic/structure_layout.dart';
import '../models/component_status.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';

/// Everything the engineering wizard collects for a single structure, plus the
/// derived stack, layout and spatial validation.
class DesignState extends ChangeNotifier {
  DesignState({
    String jobName = 'Sample Job - MH-1',
    String structureMark = 'MH-1',
    String customer = 'City of Springfield',
    StructureType structureType = StructureType.sanitaryManhole,
    DateTime? castDate,
    double rimElevationFt = 100.0,
    double invertElevationFt = 88.5,
    double sumpDepthIn = 0,
    double structureDiameterIn = 48,
    bool conicalTop = true,
    BootType defaultBoot = BootType.aLok,
    double maxGradeRingStackIn = 12.0,
    int stepCount = 6,
    List<PipePenetration>? pipes,
  })  : _jobName = jobName,
        _structureMark = structureMark,
        _customer = customer,
        _structureType = structureType,
        _castDate = castDate ?? DateTime(2026, 1, 15),
        _rimElevationFt = rimElevationFt,
        _invertElevationFt = invertElevationFt,
        _sumpDepthIn = sumpDepthIn,
        _structureDiameterIn = structureDiameterIn,
        _conicalTop = conicalTop,
        _defaultBoot = defaultBoot,
        _maxGradeRingStackIn = maxGradeRingStackIn,
        _stepCount = stepCount,
        _pipes = pipes ??
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

  String _jobName;
  String _structureMark;
  String _customer;
  StructureType _structureType;
  DateTime _castDate;
  double _rimElevationFt;
  double _invertElevationFt;
  double _sumpDepthIn;
  double _structureDiameterIn;
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
  bool get conicalTop => _conicalTop;
  BootType get defaultBoot => _defaultBoot;
  double get maxGradeRingStackIn => _maxGradeRingStackIn;
  int get stepCount => _stepCount;
  List<PipePenetration> get pipes => List.unmodifiable(_pipes);

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
        structureDiameterIn: _structureDiameterIn,
        conicalTop: _conicalTop,
        sumpDepthIn: _sumpDepthIn,
        maxGradeRingStackIn: _maxGradeRingStackIn,
      );

  StructureLayout get layout => StructureLayout(
        stack: stack,
        rimElevationFt: _rimElevationFt,
        invertElevationFt: _invertElevationFt,
        structureDiameterIn: _structureDiameterIn,
        sumpDepthIn: _sumpDepthIn,
      );

  ValidationReport get validation => const PipeValidator().validate(
        pipes: _pipes,
        structureInsideDiameterIn: _structureDiameterIn,
        wallThicknessIn: PieceCatalog.base(_structureDiameterIn).wallThicknessIn,
        rimElevationFt: _rimElevationFt,
        invertElevationFt: _invertElevationFt,
      );

  /// Names of pipes involved in at least one conflict.
  Set<String> get conflictedPipeNames => {
        for (final c in validation.conflicts) ...[c.pipeA, c.pipeB],
      };

  double get totalWeightLbs => stack.totalWeightLbs;

  /// Every physical item the yard has to produce or pull for this structure,
  /// in build order: concrete pieces, then castings and accessories.
  List<StructureComponent> buildComponents() {
    final out = <StructureComponent>[];
    var seq = 1;
    String nextId() => '$_structureMark-${(seq++).toString().padLeft(2, '0')}';

    for (final item in stack.items) {
      for (var i = 0; i < item.count; i++) {
        out.add(StructureComponent(
          id: nextId(),
          pieceId: item.piece.id,
          description: item.piece.description,
          weightLbs: item.piece.weightLbs,
          stockSku: _skuForPiece(item.piece),
        ));
      }
    }
    out.add(StructureComponent(
      id: nextId(),
      pieceId: 'LID-24',
      description: '24" Iron Frame & Lid',
      weightLbs: 320,
      stockSku: 'LID-24',
    ));
    for (final pipe in _pipes) {
      out.add(StructureComponent(
        id: nextId(),
        pieceId: pipe.boot.sku,
        description: '${pipe.boot.label} boot - ${pipe.name}',
        weightLbs: 12,
        stockSku: pipe.boot.sku,
      ));
    }
    for (var i = 0; i < _stepCount; i++) {
      out.add(StructureComponent(
        id: nextId(),
        pieceId: 'STEP-MA',
        description: 'Manhole step',
        weightLbs: 3,
        stockSku: 'STEP-MA',
      ));
    }
    return out;
  }

  static String _skuForPiece(PrecastPiece piece) => switch (piece.type) {
        PieceType.riser => 'R${piece.insideDiameterIn.toStringAsFixed(0)}',
        PieceType.gradeRing => 'GR',
        _ => piece.id,
      };
}
