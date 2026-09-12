import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/painters/label_layout.dart';

/// Records where each annotation was actually painted.
class _RecordingCanvas implements Canvas {
  final List<Rect> painted = [];

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {
    painted.add(Rect.fromLTWH(offset.dx, offset.dy, paragraph.width, paragraph.height));
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
  test('labels stay inside the canvas bounds', () {
    const size = Size(160, 90);
    final canvas = _RecordingCanvas();
    final placer = LabelPlacer(size);

    placer.draw(canvas, 'N', const Offset(80, -40), 11, align: LabelAnchor.center);
    placer.draw(canvas, 'OUT 18.0" @ 180 (6:00)', const Offset(150, 200), 9);
    placer.draw(canvas, 'IN-A', const Offset(-60, 40), 9, align: LabelAnchor.right);

    expect(canvas.painted, hasLength(3));
    for (final rect in canvas.painted) {
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
    }
  });

  test('overlapping annotations are separated vertically', () {
    final canvas = _RecordingCanvas();
    final placer = LabelPlacer(const Size(300, 200));

    placer.draw(canvas, 'IN-A 14.4" OD', const Offset(40, 80), 9);
    placer.draw(canvas, 'IN-B 18.0" OD', const Offset(40, 80), 9);
    placer.draw(canvas, 'OUT 18.0" OD', const Offset(40, 82), 9);

    for (var i = 0; i < canvas.painted.length; i++) {
      for (var j = i + 1; j < canvas.painted.length; j++) {
        expect(canvas.painted[i].overlaps(canvas.painted[j]), isFalse,
            reason: 'labels $i and $j overlap');
      }
    }
  });

  test('overlap avoidance can be opted out of', () {
    final canvas = _RecordingCanvas();
    final placer = LabelPlacer(const Size(300, 200));

    placer.draw(canvas, '90°', const Offset(40, 80), 8, avoidOverlap: false);
    placer.draw(canvas, '120°', const Offset(40, 80), 8, avoidOverlap: false);

    expect(canvas.painted[0].top, canvas.painted[1].top);
  });
}
