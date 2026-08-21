import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'code_pane_test_harness.dart';

/// Tall enough that its SingleChildScrollView has plenty to scroll inside
/// the test viewport.
final _tallCode = List.generate(400, (i) => 'final line$i = $i;').join('\n');

Widget _pane({required String code, required bool autoScroll}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: CodePane(code: code, fontSize: 14, autoScroll: autoScroll),
      ),
    ),
  );
}

/// The pane's own scroll position. The pane's ScrollController is the only
/// one in the tree; its SingleChildScrollView may contain nested
/// Scrollables (from SelectableText internals), so matching on Scrollable
/// itself is ambiguous.
ScrollPosition _panePosition(WidgetTester tester) {
  final scrollView = tester.widget<SingleChildScrollView>(
    find.byType(SingleChildScrollView),
  );
  return scrollView.controller!.position;
}

void main() {
  testWidgets('autoScroll drifts the code pane down on its own', (
    tester,
  ) async {
    await tester.pumpWidget(_pane(code: _tallCode, autoScroll: true));
    expect(_panePosition(tester).pixels, 0);

    // Past the startup beat (4.5s) plus several 50ms ticks of drift.
    await tester.pump(const Duration(seconds: 6));
    expect(_panePosition(tester).pixels, greaterThan(0));
  });

  testWidgets('without autoScroll the code pane stays put', (tester) async {
    await tester.pumpWidget(_pane(code: _tallCode, autoScroll: false));
    await tester.pump(const Duration(seconds: 6));
    expect(_panePosition(tester).pixels, 0);
  });

  testWidgets('content shorter than the viewport never scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pane(code: 'final tiny = true;', autoScroll: true),
    );
    expect(_panePosition(tester).maxScrollExtent, 0);
    await tester.pump(const Duration(seconds: 6));
    expect(_panePosition(tester).pixels, 0);
  });

  testWidgets('reaching the bottom dwells, then drifts back up', (
    tester,
  ) async {
    // Short enough that the full downward traverse finishes in well under a
    // minute (752px at 1.8px/50ms tick ≈ 21s) but still scrollable.
    final shortCode = List.generate(
      60,
      (i) => 'final line$i = $i;',
    ).join('\n');
    await tester.pumpWidget(_pane(code: shortCode, autoScroll: true));
    final maxExtent = _panePosition(tester).maxScrollExtent;
    expect(maxExtent, greaterThan(0));

    // Fake-async throttles periodic timers to one re-arm per pump frame, so
    // advance in 1s steps to let every tick fire. Watch the pane: it must
    // reach the bottom, hold there through the dwell, then reverse.
    var sawBottom = false;
    var pixelsAfterReverse = -1.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      final pixels = _panePosition(tester).pixels;
      if (pixels == maxExtent) sawBottom = true;
      if (sawBottom && pixels < maxExtent) {
        pixelsAfterReverse = pixels;
        break;
      }
    }
    expect(sawBottom, isTrue, reason: 'pane should drift to the bottom');
    expect(
      pixelsAfterReverse,
      greaterThanOrEqualTo(0),
      reason: 'pane should drift back up after dwelling at the bottom',
    );
  });
}
