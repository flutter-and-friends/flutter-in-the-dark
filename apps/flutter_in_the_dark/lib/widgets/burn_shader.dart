/// Production burn-reveal renderer: a single `CustomPaint` +
/// `FragmentProgram` that computes the burn hole, char ring, and flame rim
/// procedurally per-pixel — replacing the rasterized-ImageShader-inside-
/// dstOut-ShaderMask (`BurnHoleMask`) and the separate `BurnPainter`.
///
/// Why this is the shipped path: the mask version re-rasterized the
/// full-screen hole via `PictureRecorder.toImageSync` on EVERY frame of
/// the burn (measured 0 cache hits / 51 misses over a single 1 s burn —
/// raster p50 32 ms p90 81 ms, burn-window rAF deltas p50 50 ms p90 83 ms)
/// AND forced a full-screen dstOut saveLayer on top. This painter has no
/// `BlendMode.dstOut` (so NO saveLayer) and no per-frame rasterization —
/// the contour is pure math evaluated in the fragment shader. Measured on
/// the same machine: FrameTiming total p50 ~10 ms p90 ~45 ms.
///
/// The hole is emitted as alpha=0 pixels from this painter, which
/// composites over the layer beneath (the pre-warmed iframe) with the
/// normal source-over blend — no extra blend layer needed.
///
/// The geometry is a line-for-line port of `helpers/burn_phase.dart` +
/// `helpers/burn_edge.dart`; the seed-derived phases/amplitudes are pushed
/// in as uniforms so the silhouette matches the Dart `BurnEdge` exactly.
///
/// A fragment shader cannot draw widget TEXT, so the countdown display is
/// stacked above this painter as a normal widget and faded out as ignition
/// starts — see `BurnShaderOverlay`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/burn_edge.dart';

/// Loads the compiled burn fragment program. Shaders declared in pubspec
/// are compiled offline by `impellerc` (SkSL + JSON metadata for the web
/// build, same path as the framework's own `ink_sparkle.frag`) and bundled
/// as assets, so [ui.FragmentProgram.fromAsset] only LOADS the blob. The
/// one-time runtime-effect compile still happens on FIRST USE — see
/// [BurnShaderOverlay], which absorbs it with a hidden warmup paint when
/// the overlay mounts so it never lands mid-burn.
final Future<ui.FragmentProgram> burnProgram = ui.FragmentProgram.fromAsset(
  'shaders/burn.frag',
);

/// Paints the burn overlay (opaque paper + jagged hole + char + flame) in
/// one fragment-shader pass. The paper is a flat [paperColor]; the
/// countdown text is stacked above by [BurnShaderOverlay], not drawn here.
class BurnShaderPainter extends CustomPainter {
  BurnShaderPainter({
    required this.program,
    required this.progress,
    required this.edge,
    this.paperColor = const Color(0xFF000000),
  });

  final ui.FragmentProgram program;
  final double progress;
  final BurnEdge edge;

  /// The opaque "paper" the hole burns through (scaffold background).
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    final halfDiagonal =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final shader = program.fragmentShader()
      // u_bounds: rect is at the origin of this painter's canvas.
      ..setFloat(0, 0) // left
      ..setFloat(1, 0) // top
      ..setFloat(2, size.width)
      ..setFloat(3, size.height)
      // u_shape: progress, variation, halfDiagonal, (unused .w)
      ..setFloat(4, progress)
      ..setFloat(5, edge.variation)
      ..setFloat(6, halfDiagonal)
      ..setFloat(7, 0)
      // u_phase0/1/2
      ..setFloat(8, edge.phases[0])
      ..setFloat(9, 0)
      ..setFloat(10, 0)
      ..setFloat(11, 0)
      ..setFloat(12, edge.phases[1])
      ..setFloat(13, 0)
      ..setFloat(14, 0)
      ..setFloat(15, 0)
      ..setFloat(16, edge.phases[2])
      ..setFloat(17, 0)
      ..setFloat(18, 0)
      ..setFloat(19, 0)
      // u_amp (normalized, sum == 1)
      ..setFloat(20, edge.amplitudes[0])
      ..setFloat(21, edge.amplitudes[1])
      ..setFloat(22, edge.amplitudes[2])
      ..setFloat(23, 0)
      // u_paper
      ..setFloat(24, paperColor.r)
      ..setFloat(25, paperColor.g)
      ..setFloat(26, paperColor.b)
      ..setFloat(27, paperColor.a);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(BurnShaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      !identical(oldDelegate.edge, edge) ||
      !identical(oldDelegate.program, program) ||
      oldDelegate.paperColor != paperColor;
}

/// The production burn overlay: the shader paper + hole, the countdown
/// display stacked ABOVE it as a normal widget (faded out as ignition
/// starts), and a one-time hidden warmup paint that absorbs the runtime-
/// effect compile so it never lands mid-burn.
///
/// The text seam: a fragment shader cannot draw widget text, so instead of
/// the mask version's "text erodes per-pixel with the paper", the whole
/// countdown display fades out over the first [BurnShaderOverlay.textFadeEnd]
/// of the burn (an early Interval of the same controller). This is the
/// accepted aesthetic trade: glyphs fade out whole rather than being
/// eroded by the contour — timed so they are gone just as the hole would
/// reach them anyway.
class BurnShaderOverlay extends StatefulWidget {
  const BurnShaderOverlay({
    super.key,
    required this.progress,
    required this.edge,
    required this.countdownBuilder,
  });

  /// Burn progress 0→1 (from `BurnRevealController.burn` / the test loop).
  final double progress;

  /// The seeded jagged edge for THIS burn (fixed for the burn's duration).
  final BurnEdge edge;

  /// Builds the countdown display (big numbers etc.) — stacked above the
  /// shader paper and faded out as the burn ignites.
  final WidgetBuilder countdownBuilder;

  /// The countdown display is fully transparent by this fraction of the
  /// burn. Chosen to sit just ahead of the hole reaching the text: the
  /// mask version's text started eroding around p≈0.10–0.15, so the fade
  /// completes at p=0.15 (fade starts at p=0.02 so ignition is visible
  /// before the text reacts). See [burnTextOpacity].
  static const double textFadeStart = 0.02;
  static const double textFadeEnd = 0.15;

  @override
  State<BurnShaderOverlay> createState() => _BurnShaderOverlayState();
}

/// Opacity of the countdown display at burn progress [p]: 1 until
/// [BurnShaderOverlay.textFadeStart], 0 by [BurnShaderOverlay.textFadeEnd],
/// linear in between. Top-level so it is unit-testable without pumping the
/// overlay (W-012-adjacent: keeps the fade curve verifiable as pure logic).
double burnTextOpacity(double p) {
  const start = BurnShaderOverlay.textFadeStart;
  const end = BurnShaderOverlay.textFadeEnd;
  if (p <= start) return 1;
  if (p >= end) return 0;
  return 1.0 - (p - start) / (end - start);
}

class _BurnShaderOverlayState extends State<BurnShaderOverlay> {
  ui.FragmentProgram? _program;

  /// True once the one-time warmup paint has actually been painted. The
  /// warmup is a 1×1 [CustomPaint] with the real program at progress 0 —
  /// it forces the runtime-effect compile (~1.2 s measured) while the
  /// overlay is still opaque and idle at mount, instead of on the first
  /// burning frame.
  bool _warmedUp = false;

  @override
  void initState() {
    super.initState();
    burnProgram.then((program) {
      if (!mounted) return;
      setState(() => _program = program);
      // Drop the warmup after it has been painted once (the frame after it
      // entered the tree).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _warmedUp = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) {
      // Program still loading: hold the opaque paper so nothing beneath
      // shows early. The countdown display stays visible on top.
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          widget.countdownBuilder(context),
        ],
      );
    }

    final paperColor = Theme.of(context).scaffoldBackgroundColor;
    final opacity = burnTextOpacity(widget.progress);

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: BurnShaderPainter(
            program: program,
            progress: widget.progress,
            edge: widget.edge,
            paperColor: paperColor,
          ),
          child: const SizedBox.expand(),
        ),
        if (opacity > 0)
          IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: widget.countdownBuilder(context),
            ),
          ),
        // One-time hidden warmup: a 1×1 paint with the real program so the
        // runtime-effect compile happens at mount, not mid-burn.
        if (!_warmedUp)
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: CustomPaint(
              painter: BurnShaderPainter(
                program: program,
                progress: 0,
                edge: widget.edge,
                paperColor: paperColor,
              ),
            ),
          ),
      ],
    );
  }
}
