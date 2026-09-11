import '../logic/stack_calculator.dart';

class BomLine {
  const BomLine({
    required this.mark,
    required this.description,
    required this.count,
    required this.unitWeightLbs,
    required this.heightIn,
  });

  final String mark;
  final String description;
  final int count;
  final double unitWeightLbs;
  final double heightIn;

  double get totalWeightLbs => unitWeightLbs * count;
  double get totalHeightIn => heightIn * count;
}

/// Collapses the stack into one line per catalog piece, heaviest first.
List<BomLine> buildBillOfMaterials(StackResult stack) {
  final grouped = <String, BomLine>{};
  for (final item in stack.items) {
    final existing = grouped[item.piece.id];
    grouped[item.piece.id] = BomLine(
      mark: item.piece.id,
      description: item.piece.description,
      count: (existing?.count ?? 0) + item.count,
      unitWeightLbs: item.piece.weightLbs,
      heightIn: item.piece.heightIn,
    );
  }
  final lines = grouped.values.toList()
    ..sort((a, b) => b.totalWeightLbs.compareTo(a.totalWeightLbs));
  return lines;
}
