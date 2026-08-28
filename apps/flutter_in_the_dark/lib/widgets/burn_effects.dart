/// The shared burn visuals: the jagged erase hole, the charred ring and
/// the flame rim. Used by BOTH the production overlay
/// (`widgets/burn_reveal.dart`) and the standalone `/burn_test` page
/// (`screens/burn_test_screen.dart`) — previously each kept a private,
/// byte-identical copy of a radial-gradient implementation, which drifted
/// the moment the edge became jagged (angular noise) instead of circular.
///
/// [BurnHoleMask] is a single `ShaderMask` + `BlendMode.dstOut` whose
/// shader is an [ImageShader] rasterized from the blurred jagged hole
/// path — the direct jagged analogue of the old radial-gradient shader
/// (white/erased inside → transparent/kept outside), and the only mask
/// shape that erases a see-through hole on every engine (see the class
/// doc for why the nested dstIn+dstOut composition cancelled out).
///
/// The edge is jagged: `BurnEdge` (`helpers/burn_edge.dart`) perturbs the
/// hole/char/flame radii per-angle with a seeded, periodic angular noise,
/// so every run's silhouette differs but is STABLE for the burn's duration
/// (a fresh seed per burn — never per frame — so the shape scales outward
/// with progress without shimmering).
///
/// PRODUCTION uses the `FragmentProgram` rewrite in `burn_shader.dart`
/// (see that file for why — the dstOut mask forced a full-screen saveLayer
/// plus a full-screen `toImageSync` re-raster EVERY frame of the burn).
/// This mask implementation is kept as the `/burn_test` A/B baseline
/// (`?burnMode=mask`) and for the structural widget tests in
/// `test/burn_effects_test.dart`.
///
/// This file imports `package:flutter/material.dart`, NOT `package:web`,
/// so it stays widget-test friendly. It still must not be imported from
/// `helpers/` (W-012): pure geometry lives in `burn_edge.dart` /
/// `burn_phase.dart`; this is only the rasterization.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';
import 'package:flutter_in_the_dark/helpers/burn_phase.dart';

/// Builds a closed [Path] through [points] (offsets relative to [center]).
/// Used as a tear-off (`BurnHoleMask`/`BurnPainter` take it as a callback)
/// so the pure geometry stays decoupled from `Path` and unit-testable.
typedef BurnPathBuilder = Path Function(
  List<BurnEdgePoint> points,
  Offset center,
);

/// The default [BurnPathBuilder]: straight segments between the 96 sample
/// points. At that density a polyline is visually smooth at burn scale —
/// no curve fitting needed.
Path polygonBurnPath(List<BurnEdgePoint> points, Offset center) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(center.dx + points.first.x, center.dy + points.first.y);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(center.dx + points[i].x, center.dy + points[i].y);
  }
  path.close();
  return path;
}

/// The erase mask for the burn hole — replaces the old radial-gradient
/// `ShaderMask` shader, which could only ever cut a circle.
///
/// Rendering: a SINGLE `ShaderMask` + `BlendMode.dstOut` over the "paper"
/// (the countdown display), exactly like the old radial version that
/// worked. The shader is an [ImageShader] rasterized from a picture of the
/// jagged hole path, drawn opaque and blurred by the char-band width:
/// alpha 1 (erase) inside the perturbed hole, a soft falloff to alpha 0
/// (keep) across exactly the band the char ring paints. For dstOut the
/// result is `paper × (1 − mask.alpha)`, so the hole punches through to
/// the layer beneath while the unburned paper is untouched.
///
/// Why NOT two nested masks: a `dstIn` inner mask that cuts the hole out
/// of the paper first leaves the hole region transparent, so a `dstOut`
/// outer mask has nothing left to erase there — and on canvaskit a
/// full-screen `dstOut` ShaderMask is realized as a saveLayer whose
/// restore blends with dstOut, wiping the entire already-rasterized frame
/// beneath the overlay instead of just the hole. One mask whose shader IS
/// the hole is the only shape that is correct on every engine.
class BurnHoleMask extends StatelessWidget {
  const BurnHoleMask({
    super.key,
    required this.progress,
    required this.edge,
    required this.child,
    this.pathBuilder = polygonBurnPath,
  });

  /// Burn progress 0→1 (from `BurnRevealController.burn` / the test loop).
  final double progress;

  /// The seeded jagged edge for THIS burn (fixed for the burn's duration).
  final BurnEdge edge;

  /// The "paper" that burns away (opaque base + countdown display).
  final Widget child;

  /// How the sampled contour becomes a [Path]. Injectable for tests.
  final BurnPathBuilder pathBuilder;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstOut,
      shaderCallback: _holeShader,
      child: child,
    );
  }

  Shader _holeShader(Rect bounds) {
    final center = bounds.center;
    final halfDiagonal =
        math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) /
            2;
    final sample = sampleBurn(progress);
    final hole = sample.holeRadius * halfDiagonal;
    final charWidth =
        math.max((sample.charRadius - sample.holeRadius) * halfDiagonal, 1.0);
    // Before the hole opens there is nothing to erase: a fully transparent
    // shader keeps dstOut a no-op (paper × (1 − 0) = paper).
    if (hole <= 0) return _transparentStrip;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawPath(
      pathBuilder(edge.contourPoints(hole), center),
      Paint()
        // Opaque white inside the hole → erase there. The blur feathers
        // the edge outward by ≈ the char band width, so the erase falls
        // off across exactly the band the char ring paints (dstOut uses
        // only the mask's alpha; the color only needs an alpha channel).
        ..color = const Color(0xFFFFFFFF)
        // `drawPath` on the recorder is not anti-aliased by a MaskFilter,
        // so the blur IS the feather.
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, charWidth / 2),
    );
    return ImageShader(
      recorder
          .endRecording()
          .toImageSync(bounds.width.ceil(), bounds.height.ceil()),
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );
  }
}

/// Paints the charred ring and flame rim along the SAME jagged contour the
/// [BurnHoleMask] erases (perturbed outward by the char/flame band widths,
/// from [sampleBurnAt]) — replacing the old `drawCircle` painter, which
/// could only draw round rings that no longer hug the burn edge.
///
/// The radial gradients of the circular version become layered strokes of
/// the jagged hole path, widening/blurring outward — dark char first, then
/// orange ember, then a tight hot yellow-white core — so the glow still
/// falls off away from the edge but now follows the wavy boundary.
class BurnPainter extends CustomPainter {
  BurnPainter({
    required this.progress,
    required this.edge,
    this.pathBuilder = polygonBurnPath,
  });

  final double progress;

  /// The SAME [BurnEdge] instance the [BurnHoleMask] erased with — the
  /// char and flame must ride the identical contour.
  final BurnEdge edge;

  /// How the sampled contour becomes a [Path]. Injectable for tests.
  final BurnPathBuilder pathBuilder;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = size.center(Offset.zero);
    final halfDiagonal =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final sample = sampleBurn(progress);
    final hole = sample.holeRadius * halfDiagonal;
    if (hole <= 0) return;
    final charWidth =
        math.max((sample.charRadius - sample.holeRadius) * halfDiagonal, 1.0);
    final flameWidth =
        math.max((sample.flameRadius - sample.holeRadius) * halfDiagonal, 1.0);
    final rim = sample.rimAlpha;

    final holePath = pathBuilder(edge.contourPoints(hole), center);

    // Charred ring: darkened paper edge just OUTSIDE the hole — an even
    // stroke centered half a band out, blurred soft (char has no crisp
    // edge on real paper).
    canvas.drawPath(
      holePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = charWidth
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, charWidth / 2)
        ..color = const Color(0xF22B1408),
    );

    if (rim > 0) {
      // Flame rim, outside-in: a wide deep-orange ember glow…
      canvas.drawPath(
        holePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = flameWidth
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, flameWidth / 2)
          ..color =
              const Color(0xFFFF3C00).withValues(alpha: rim * 0.35),
      );
      // …a mid orange band…
      canvas.drawPath(
        holePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = charWidth * 1.2
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, charWidth / 2)
          ..color =
              const Color(0xFFFF6D00).withValues(alpha: rim * 0.85),
      );
      // …and the hot yellow-white core hugging the hole's edge, drawn as a
      // drop shadow toward the unburned side so it doesn't bleed into the
      // revealed challenge.
      canvas.drawShadow(
        holePath,
        const Color(0xFFFFD740).withValues(alpha: rim),
        6,
        false,
      );
    }
  }

  @override
  bool shouldRepaint(BurnPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      !identical(oldDelegate.edge, edge) ||
      !identical(oldDelegate.pathBuilder, pathBuilder);
}

/// A 1×1 fully-transparent strip, tiled: the erase mask before the hole
/// opens (progress 0). dstOut with a zero-alpha mask is a no-op
/// (`paper × (1 − 0) = paper`), so the paper stays fully intact.
Shader get _transparentStrip {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0x00000000),
  );
  return ImageShader(
    recorder.endRecording().toImageSync(1, 1),
    TileMode.clamp,
    TileMode.clamp,
    Matrix4.identity().storage,
  );
}
