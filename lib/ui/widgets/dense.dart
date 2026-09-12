import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mh_theme.dart';

/// Dark section header bar, as used above each block of spreadsheet rows.
class SectionBar extends StatelessWidget {
  const SectionBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Mh.headerHeight,
      color: Mh.chrome,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Mh.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A framed block of dense rows.
class SpecPanel extends StatelessWidget {
  const SpecPanel({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Mh.gap),
      decoration: BoxDecoration(
        color: Mh.field,
        border: Border.all(color: Mh.gridLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionBar(title: title, trailing: trailing),
          ...children,
        ],
      ),
    );
  }
}

/// One label / value row of a spec sheet.
class SpecRow extends StatelessWidget {
  const SpecRow({super.key, required this.label, required this.child, this.labelWidth = 150});

  final String label;
  final Widget child;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Mh.gridLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: labelWidth,
            constraints: const BoxConstraints(minHeight: Mh.rowHeight),
            decoration: const BoxDecoration(
              color: Mh.headerFill,
              border: Border(right: BorderSide(color: Mh.gridLine)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Text(label, style: Mh.label),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact text cell that commits on change, so tabbing between cells keeps
/// the model in sync without an explicit save.
class DenseField extends StatefulWidget {
  const DenseField({
    super.key,
    required this.value,
    required this.onChanged,
    this.numeric = false,
    this.suffix,
    this.textAlign,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool numeric;
  final String? suffix;
  final TextAlign? textAlign;

  @override
  State<DenseField> createState() => _DenseFieldState();
}

class _DenseFieldState extends State<DenseField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant DenseField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_hasFocus) {
      _controller.text = widget.value;
    }
  }

  bool _hasFocus = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => _hasFocus = f,
      child: TextField(
        controller: _controller,
        style: widget.numeric ? Mh.cellNum : Mh.cell,
        textAlign: widget.textAlign ?? (widget.numeric ? TextAlign.right : TextAlign.left),
        keyboardType: widget.numeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        inputFormatters: widget.numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
            : const <TextInputFormatter>[],
        decoration: InputDecoration(suffixText: widget.suffix, suffixStyle: Mh.label),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// Compact dropdown cell.
class DenseDropdown<T> extends StatelessWidget {
  const DenseDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      style: Mh.cell,
      borderRadius: BorderRadius.zero,
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      // Keep the closed field on one line; long catalog descriptions would
      // otherwise wrap out of the dense cell.
      selectedItemBuilder: (context) => [
        for (final item in items)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              labelOf(item),
              style: Mh.cell,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(labelOf(item), style: Mh.cell),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Header row of a data grid.
class GridHeaderRow extends StatelessWidget {
  const GridHeaderRow({super.key, required this.columns});

  /// (label, flex) pairs.
  final List<(String, int)> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Mh.headerHeight,
      decoration: const BoxDecoration(
        color: Mh.headerFill,
        border: Border(bottom: BorderSide(color: Mh.gridLine)),
      ),
      child: Row(
        children: [
          for (final (label, flex) in columns)
            Expanded(
              flex: flex,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Mh.gridLine)),
                ),
                child: Text(label.toUpperCase(), style: Mh.header, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }
}

/// Body row of a data grid; cells are laid out with the same flex weights as
/// the header.
class GridRow extends StatelessWidget {
  const GridRow({super.key, required this.cells, this.highlight, this.striped = false});

  final List<(Widget, int)> cells;
  final Color? highlight;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ?? (striped ? const Color(0xFFF8F9FB) : Mh.field),
        border: const Border(bottom: BorderSide(color: Mh.gridLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (cell, flex) in cells)
            Expanded(
              flex: flex,
              child: Container(
                constraints: const BoxConstraints(minHeight: Mh.rowHeight),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Mh.gridLine)),
                ),
                alignment: Alignment.centerLeft,
                child: cell,
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps a column of grid rows so that on screens narrower than [minWidth]
/// the grid scrolls horizontally instead of squeezing every cell into a few
/// unreadable characters.
class DenseGrid extends StatelessWidget {
  const DenseGrid({super.key, required this.rows, this.minWidth = 700});

  final List<Widget> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final grid = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minWidth) return grid;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: grid),
        );
      },
    );
  }
}

/// Small status chip used across logistics and inventory views.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.dense = true});

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 8, vertical: dense ? 1 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: dense ? 9.5 : 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

double? parseNum(String raw) => double.tryParse(raw.trim());

/// Parses a dimension typed the way the shop writes it: plain inches (`48`,
/// `48"`), feet (`4'`), or feet and inches (`4'6`, `4' 6"`). Returns inches.
double? parseFeetInches(String raw) {
  final text = raw.trim().replaceAll('"', '').replaceAll('\u201D', '');
  if (text.isEmpty) return null;
  final foot = text.indexOf("'");
  if (foot < 0) return double.tryParse(text);
  final feet = double.tryParse(text.substring(0, foot).trim());
  if (feet == null) return null;
  final rest = text.substring(foot + 1).trim();
  final inches = rest.isEmpty ? 0.0 : double.tryParse(rest);
  if (inches == null) return null;
  return feet * 12 + inches;
}
