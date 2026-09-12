/// Drainage flow tree: structures chained by the structure each one discharges
/// into. The downstream-most structure (an outfall with no downstream mark) is
/// the root, with upstream branches nested inside it.
class FlowNode<T> {
  FlowNode({required this.mark, required this.value, List<FlowNode<T>>? children})
    : children = children ?? [];

  final String mark;
  final T value;
  final List<FlowNode<T>> children;

  /// Total nodes in this branch, including itself.
  int get size => 1 + children.fold(0, (sum, c) => sum + c.size);
}

/// Builds the nested flow tree for [items].
///
/// [markOf] is the structure's unique name, [downstreamOf] the mark it flows
/// into. Items whose downstream mark is missing, unknown, self-referencing or
/// part of a cycle are treated as roots so nothing is ever dropped. Children
/// are ordered alphabetically.
List<FlowNode<T>> buildFlowTree<T>(
  List<T> items, {
  required String Function(T) markOf,
  required String? Function(T) downstreamOf,
}) {
  final nodes = <String, FlowNode<T>>{};
  for (final item in items) {
    nodes[markOf(item)] = FlowNode<T>(mark: markOf(item), value: item);
  }

  final roots = <FlowNode<T>>[];
  for (final item in items) {
    final mark = markOf(item);
    final node = nodes[mark]!;
    final parentMark = downstreamOf(item);
    final parent = parentMark == null || parentMark == mark ? null : nodes[parentMark];
    if (parent == null || _reaches(items, markOf, downstreamOf, parentMark!, mark)) {
      roots.add(node);
    } else {
      parent.children.add(node);
    }
  }

  void sort(List<FlowNode<T>> list) {
    list.sort((a, b) => a.mark.compareTo(b.mark));
    for (final n in list) {
      sort(n.children);
    }
  }

  sort(roots);
  return roots;
}

/// Whether following downstream links from [from] arrives at [target], which
/// would make the link a cycle.
bool _reaches<T>(
  List<T> items,
  String Function(T) markOf,
  String? Function(T) downstreamOf,
  String from,
  String target,
) {
  final byMark = {for (final item in items) markOf(item): item};
  final seen = <String>{};
  var current = from;
  while (seen.add(current)) {
    if (current == target) return true;
    final item = byMark[current];
    final next = item == null ? null : downstreamOf(item);
    if (next == null) return false;
    current = next;
  }
  return true;
}
