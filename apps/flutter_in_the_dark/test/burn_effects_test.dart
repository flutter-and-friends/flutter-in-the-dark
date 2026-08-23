import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/widgets/burn_effects.dart';
import 'package:flutter_test/flutter_test.dart';

/// Structural regression tests for the burn-hole erase mask.
///
/// The reveal was lost once when `BurnHoleMask` became two NESTED
/// ShaderMasks (inner dstIn + outer dstOut around a 1×1 white strip): the
/// dstIn cut the hole out of the paper first, so the dstOut had nothing
/// left to erase there — and on canvaskit the full-screen dstOut layer is
/// realized as a saveLayer whose restore blends dstOut over the whole
/// already-rasterized frame, wiping the revealed layer beneath instead of
/// punching a hole. The working shape — before and now again — is a
/// SINGLE dstOut ShaderMask whose shader image itself is the soft jagged
/// hole (alpha 1 inside → erase, feathering to 0 across the char band →
/// keep). These tests pin that structure so the nesting cannot creep
/// back in.
void main() {
  Widget mask({double progress = 0.5}) {
    return MaterialApp(
      home: Scaffold(
        body: BurnHoleMask(
          progress: progress,
          edge: BurnEdge(seed: 7),
          child: const ColoredBox(
            color: Colors.black,
            child: Center(child: Text('paper')),
          ),
        ),
      ),
    );
  }

  testWidgets('BurnHoleMask is a single dstOut ShaderMask — never nested', (
    tester,
  ) async {
    await tester.pumpWidget(mask());

    final masks = tester
        .widgetList<ShaderMask>(find.byType(ShaderMask))
        .toList();
    expect(
      masks,
      hasLength(1),
      reason:
          'a nested dstIn/dstOut pair cancels out and loses the reveal '
          '(see test doc); the mask must stay a single ShaderMask',
    );
    expect(
      masks.single.blendMode,
      BlendMode.dstOut,
      reason: 'dstOut erases the paper where the hole shader is opaque',
    );
    // The paper child must remain the ShaderMask's child — the mask
    // erases through IT down to the layer beneath.
    expect(find.text('paper'), findsOneWidget);
  });

  testWidgets('the hole shader is an ImageShader of the jagged path', (
    tester,
  ) async {
    await tester.pumpWidget(mask());

    final maskWidget = tester.widget<ShaderMask>(find.byType(ShaderMask));
    final shader = maskWidget.shaderCallback(
      const Rect.fromLTWH(0, 0, 800, 600),
    );
    expect(
      shader,
      isA<ImageShader>(),
      reason:
          'the jagged soft hole is rasterized into an ImageShader; a '
          'radial gradient could only cut a circle',
    );
  });

  testWidgets('progress 0 yields a transparent (no-op) mask — paper intact', (
    tester,
  ) async {
    await tester.pumpWidget(mask(progress: 0));

    final maskWidget = tester.widget<ShaderMask>(find.byType(ShaderMask));
    // Must not throw and must still produce a shader (a fully transparent
    // strip: dstOut with a zero-alpha mask keeps the paper untouched).
    final shader = maskWidget.shaderCallback(
      const Rect.fromLTWH(0, 0, 800, 600),
    );
    expect(shader, isA<ImageShader>());
  });

  test('polygonBurnPath closes a non-empty contour around the center', () {
    final edge = BurnEdge(seed: 42);
    final points = edge.contourPoints(200);
    final path = polygonBurnPath(points, const Offset(400, 300));

    // The path must actually cover the hole region (otherwise dstOut has
    // nothing to erase) and reach out to roughly the contour radius.
    expect(path.contains(const Offset(400, 300)), isTrue);
    expect(
      path.contains(const Offset(400, 300 + 199 * BurnEdge.minScale)),
      isTrue,
    );
    final bounds = path.getBounds();
    expect(bounds.width, greaterThan(300));
    expect(bounds.height, greaterThan(300));
    // Wobble keeps the silhouette inside the hard scale bounds.
    expect(bounds.width, lessThan(2 * 200 * BurnEdge.maxScale + 1));
  });
}
