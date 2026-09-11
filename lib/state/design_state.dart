import 'package:flutter/foundation.dart';

import '../logic/pipe_validator.dart';
import '../logic/stack_calculator.dart';
import '../logic/structure_layout.dart';
import '../models/pipe_penetration.dart';
import '../models/precast_piece.dart';

/// Single source of truth for the manhole currently being designed.
class DesignState extends ChangeNotifier {
  DesignState({
    String jobName = 'Sample Job - MH-1',
    double rimElevationFt = 100.0,
    double invertElevationFt = 88.5,
    double structureDiameterIn = 48,
    bool conicalTop = true,
    List<PipePenetration>? pipes,
  })  : _jobName = jobName,
        _rimElevationFt = rimElevationFt,
        _invertElevationFt = invertElevationFt,
        _structureDiameterIn = structureDiameterIn,
        _conicalTop = conicalTop,
        _pipes = pipes ??
            [
              PipePenetration(
                name: 'IN-A',
                outsideDiameterIn: 14.4,
                invertElevationFt: 89.0,
                horizontalAngleDeg: 0,
              ),
              PipePenetration(
                name: 'OUT',
                outsideDiameterIn: 18.0,
                invertElevationFt: 88.5,
                horizontalAngleDeg: 180,
              ),
            ];

  String _jobName;
  double _rimElevationFt;
  double _invertElevationFt;
  double _structureDiameterIn;
  bool _conicalTop;
  final List<PipePenetration> _pipes;

  String get jobName => _jobName;
  double get rimElevationFt => _rimElevationFt;
  double get invertElevationFt => _invertElevationFt;
  double get structureDiameterIn => _structureDiameterIn;
  bool get conicalTop => _conicalTop;
  List<PipePenetration> get pipes => List.unmodifiable(_pipes);

  set jobName(String value) {
    _jobName = value;
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

  set structureDiameterIn(double value) {
    _structureDiameterIn = value;
    notifyListeners();
  }

  set conicalTop(bool value) {
    _conicalTop = value;
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
      );

  StructureLayout get layout => StructureLayout(
        stack: stack,
        rimElevationFt: _rimElevationFt,
        invertElevationFt: _invertElevationFt,
        structureDiameterIn: _structureDiameterIn,
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
}
