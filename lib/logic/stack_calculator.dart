import '../models/precast_piece.dart';
import '../models/structure_size.dart';

/// One line of the resulting stack, ordered bottom (index 0) to top.
class StackItem {
  const StackItem({required this.piece, required this.count});

  final PrecastPiece piece;
  final int count;

  double get totalHeightIn => piece.heightIn * count;
  double get totalWeightLbs => piece.weightLbs * count;
}

class StackResult {
  const StackResult({
    required this.items,
    required this.structuralDepthIn,
    required this.achievedHeightIn,
    required this.residualIn,
    required this.messages,
    required this.feasible,
  });

  /// Pieces ordered bottom to top.
  final List<StackItem> items;

  /// Rim minus invert minus the 8" base floor, in inches.
  final double structuralDepthIn;

  /// Sum of the laying heights of every piece, in inches.
  final double achievedHeightIn;

  /// structuralDepth - achievedHeight. Positive means the stack is short.
  final double residualIn;

  final List<String> messages;
  final bool feasible;

  int get totalPieceCount => items.fold(0, (s, i) => s + i.count);

  /// Horizontal joints between stacked pieces (one fewer than the piece count).
  int get jointCount => totalPieceCount > 0 ? totalPieceCount - 1 : 0;

  double get totalWeightLbs => items.fold(0.0, (s, i) => s + i.totalWeightLbs);

  bool get isExact => residualIn.abs() < 0.01;
}

/// Calculates the barrel build-up for a manhole.
class StackCalculator {
  const StackCalculator();

  /// Structural depth per the shop standard: rim minus invert, plus any sump
  /// carried below the outlet invert, minus the 8" base floor slab.
  static double structuralDepthIn({
    required double rimElevationFt,
    required double invertElevationFt,
    double sumpDepthIn = 0,
    double baseFloorThicknessIn = kBaseFloorThicknessIn,
  }) => (rimElevationFt - invertElevationFt) * 12.0 + sumpDepthIn - baseFloorThicknessIn;

  /// Builds the stack that reaches [rimElevationFt] exactly while using the
  /// fewest possible pieces (and therefore the fewest horizontal joints).
  StackResult calculate({
    required double rimElevationFt,
    required double invertElevationFt,
    required StructureSize size,
    required bool conicalTop,
    double sumpDepthIn = 0,
    double maxGradeRingStackIn = 12.0,
    double baseFloorThicknessIn = kBaseFloorThicknessIn,
  }) {
    final messages = <String>[];
    final depth = structuralDepthIn(
      rimElevationFt: rimElevationFt,
      invertElevationFt: invertElevationFt,
      sumpDepthIn: sumpDepthIn,
      baseFloorThicknessIn: baseFloorThicknessIn,
    );

    if (depth <= 0) {
      return StackResult(
        items: const [],
        structuralDepthIn: depth,
        achievedHeightIn: 0,
        residualIn: depth,
        messages: [
          'Rim elevation must be above the invert elevation by more than the '
              '${baseFloorThicknessIn.toStringAsFixed(0)}" base floor.',
        ],
        feasible: false,
      );
    }

    final set = PieceCatalog.forSize(size);
    final base = set.base;
    final top = set.top(conical: conicalTop);
    if (conicalTop && !set.hasConicalTop) {
      messages.add('Box structures have no conical form - stacked with a ${top.description}.');
    }
    final fixedHeight = base.heightIn + top.heightIn;

    if (depth < fixedHeight) {
      messages.add(
        'Structural depth of ${depth.toStringAsFixed(1)}" is less than the minimum '
        '${fixedHeight.toStringAsFixed(1)}" required for a ${base.description} with a ${top.description}.',
      );
      return StackResult(
        items: [
          StackItem(piece: base, count: 1),
          StackItem(piece: top, count: 1),
        ],
        structuralDepthIn: depth,
        achievedHeightIn: fixedHeight,
        residualIn: depth - fixedHeight,
        messages: messages,
        feasible: false,
      );
    }

    final remaining = depth - fixedHeight;
    final fill = _bestFill(
      targetIn: remaining,
      risers: set.risers,
      gradeRings: set.gradeRings,
      maxGradeRingStackIn: maxGradeRingStackIn,
    );

    final items = <StackItem>[
      StackItem(piece: base, count: 1),
      for (final r in fill.risers) StackItem(piece: r.key, count: r.value),
      StackItem(piece: top, count: 1),
      for (final g in fill.gradeRings) StackItem(piece: g.key, count: g.value),
    ];

    final achieved = items.fold(0.0, (s, i) => s + i.totalHeightIn);
    final residual = depth - achieved;

    if (residual.abs() >= 0.01) {
      messages.add(
        'No exact combination of stock pieces reaches the rim: '
        '${residual > 0 ? "short" : "over"} by ${residual.abs().toStringAsFixed(2)}". '
        'Adjust with cast-in-place grade adjustment or a custom riser.',
      );
    }
    if (fill.gradeRingHeightIn > maxGradeRingStackIn) {
      messages.add(
        'Grade ring stack of ${fill.gradeRingHeightIn.toStringAsFixed(0)}" exceeds the '
        '${maxGradeRingStackIn.toStringAsFixed(0)}" recommended maximum.',
      );
    }

    return StackResult(
      items: items,
      structuralDepthIn: depth,
      achievedHeightIn: achieved,
      residualIn: residual,
      messages: messages,
      feasible: true,
    );
  }

  _Fill _bestFill({
    required double targetIn,
    required List<PrecastPiece> risers,
    required List<PrecastPiece> gradeRings,
    required double maxGradeRingStackIn,
  }) {
    final target = targetIn.round();
    if (target <= 0) return const _Fill([], [], 0);

    final maxGr = maxGradeRingStackIn.round();

    // state[h][g] = fewest pieces to build exactly h inches using g inches of
    // grade rings. Grade rings only ever sit on top of the cone/slab, so the
    // grade ring inches are tracked separately and capped.
    final inf = 1 << 28;
    final cost = List.generate(target + 1, (_) => List<int>.filled(maxGr + 1, inf));
    final choice = List.generate(target + 1, (_) => List<PrecastPiece?>.filled(maxGr + 1, null));
    cost[0][0] = 0;

    for (var h = 0; h <= target; h++) {
      for (var g = 0; g <= maxGr; g++) {
        if (cost[h][g] == inf) continue;
        for (final r in risers) {
          final nh = h + r.heightIn.round();
          if (nh > target) continue;
          if (cost[h][g] + 1 < cost[nh][g]) {
            cost[nh][g] = cost[h][g] + 1;
            choice[nh][g] = r;
          }
        }
        for (final gr in gradeRings) {
          final step = gr.heightIn.round();
          final nh = h + step;
          final ng = g + step;
          if (nh > target || ng > maxGr) continue;
          if (cost[h][g] + 1 < cost[nh][ng]) {
            cost[nh][ng] = cost[h][g] + 1;
            choice[nh][ng] = gr;
          }
        }
      }
    }

    // Prefer an exact fit; otherwise fall back to the closest achievable height
    // (closest first, then fewest pieces).
    var bestH = -1;
    var bestG = -1;
    var bestKey = (inf, inf, inf);
    for (var h = 0; h <= target; h++) {
      for (var g = 0; g <= maxGr; g++) {
        if (cost[h][g] == inf) continue;
        final key = ((target - h).abs(), cost[h][g], g);
        if (_less(key, bestKey)) {
          bestKey = key;
          bestH = h;
          bestG = g;
        }
      }
    }
    if (bestH < 0) return const _Fill([], [], 0);

    final riserCounts = <PrecastPiece, int>{};
    final gradeRingCounts = <PrecastPiece, int>{};
    var h = bestH;
    var g = bestG;
    var gradeRingHeight = 0.0;
    while (h > 0) {
      final piece = choice[h][g];
      if (piece == null) break;
      if (piece.type == PieceType.gradeRing) {
        gradeRingCounts.update(piece, (v) => v + 1, ifAbsent: () => 1);
        gradeRingHeight += piece.heightIn;
        g -= piece.heightIn.round();
      } else {
        riserCounts.update(piece, (v) => v + 1, ifAbsent: () => 1);
      }
      h -= piece.heightIn.round();
    }

    int byHeightDesc(MapEntry<PrecastPiece, int> a, MapEntry<PrecastPiece, int> b) =>
        b.key.heightIn.compareTo(a.key.heightIn);

    return _Fill(
      riserCounts.entries.toList()..sort(byHeightDesc),
      gradeRingCounts.entries.toList()..sort(byHeightDesc),
      gradeRingHeight,
    );
  }

  bool _less((int, int, int) a, (int, int, int) b) {
    if (a.$1 != b.$1) return a.$1 < b.$1;
    if (a.$2 != b.$2) return a.$2 < b.$2;
    return a.$3 < b.$3;
  }
}

class _Fill {
  const _Fill(this.risers, this.gradeRings, this.gradeRingHeightIn);

  final List<MapEntry<PrecastPiece, int>> risers;
  final List<MapEntry<PrecastPiece, int>> gradeRings;
  final double gradeRingHeightIn;
}
