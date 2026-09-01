import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// The texts the title glitches between, in no fixed order — the next one is
/// picked at random (never the currently-settled one) on every cycle.
const kGlitchTitleTexts = [
  'FLUTTER IN THE DARK',
  'VIBING IN THE DARK',
  'PROMPTING IN THE DARK',
];

/// Character pool the scramble phase draws replacement glyphs from.
const kGlitchGlyphs = '!<>-_\\/[]{}=+*^?#@%&';

/// Deterministic per-(character, tick) hash. The scramble must NOT consume
/// the injected [Random] per frame — that would make the dwell/next-text
/// sequence frame-rate dependent — so mid-glitch glyphs come from this
/// instead, keeping the whole widget deterministic under a seeded [Random].
int _glitchHash(int index, int tick) {
  final h = index * 31 + tick * 131 + 7;
  return (h * 1103515245 + 12345) & 0x7FFFFFFF;
}

/// Returns [base] with each non-space character replaced by a glyph from
/// [glyphs] with probability [intensity] (0 = untouched, 1 = fully
/// scrambled). Deterministic for a given [tick]: bump the tick to re-roll.
/// Pure — unit-tested without Flutter bindings.
String scrambleGlitchText(
  String base, {
  required double intensity,
  required int tick,
  String glyphs = kGlitchGlyphs,
}) {
  if (intensity <= 0) {
    return base;
  }
  final chars = base.split('');
  for (var i = 0; i < chars.length; i++) {
    if (chars[i] == ' ') {
      continue;
    }
    final h = _glitchHash(i, tick);
    if ((h % 1000) / 1000.0 < intensity) {
      chars[i] = glyphs[(h ~/ 1000) % glyphs.length];
    }
  }
  return chars.join();
}

/// Uniformly picks an index in `0..count-1` that is NOT [current] — the next
/// text is random, but never an immediate repeat. Pure — unit-tested.
int pickNextGlitchIndex(int current, int count, Random random) {
  if (count < 2) {
    return current;
  }
  var next = random.nextInt(count - 1);
  if (next >= current) {
    next++;
  }
  return next;
}

/// Big display title that sits settled on one text, then every few seconds
/// glitches — RGB-split offset layers over character scrambling — and
/// resolves onto a randomly chosen next text (see [kGlitchTitleTexts]).
///
/// Self-contained by design (imports only flutter/material + dart:*): the
/// player-selection screen transitively imports `dart:js_interop` through
/// the challenge screen and cannot be widget-tested (W-012), so this widget
/// carries zero project imports and is tested directly.
///
/// Fake-async friendly (I-017): the dwell between glitches is a [Timer] and
/// the transition an [AnimationController] — both advance under
/// `tester.pump`. Randomness (dwell jitter + next-text pick) comes from the
/// injected [random] (I-022), so tests are deterministic with a seed.
class GlitchTitle extends StatefulWidget {
  const GlitchTitle({
    super.key,
    this.texts = kGlitchTitleTexts,
    this.random,
    this.baseDwell = const Duration(seconds: 5),
    this.dwellJitter = const Duration(seconds: 2),
    this.glitchDuration = const Duration(milliseconds: 700),
    this.style,
    this.maxWidth = 720,
  });

  /// The texts to glitch between. Settles on `texts.first` initially.
  final List<String> texts;

  /// Randomness source for dwell jitter and next-text selection. Inject a
  /// seeded [Random] in tests; defaults to an unseeded [Random].
  final Random? random;

  /// Base dwell between glitch transitions; the actual dwell is
  /// `baseDwell + random jitter in [0, dwellJitter]`.
  final Duration baseDwell;

  /// Upper bound of the randomized dwell addition. Zero = fixed dwell.
  final Duration dwellJitter;

  /// Length of one glitch transition. The scramble ramps up to the midpoint
  /// — where the text swaps — then decodes back down onto the new text.
  final Duration glitchDuration;

  /// Settled-state text style, used as-is — including any shadows (the
  /// glitch effect layers never inherit them). Defaults to the theme's
  /// displaySmall, bold with wide letter spacing and one tight white glow.
  final TextStyle? style;

  /// Width budget for the title; the text scales down (never wraps) to fit.
  final double maxWidth;

  @override
  State<GlitchTitle> createState() => _GlitchTitleState();
}

class _GlitchTitleState extends State<GlitchTitle>
    with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final AnimationController _glitch = AnimationController(
    vsync: this,
    duration: widget.glitchDuration,
  )..addStatusListener(_onGlitchStatus);

  Timer? _dwellTimer;
  var _index = 0;
  var _pendingIndex = 0;
  var _glitching = false;

  /// The scramble re-rolls per animation frame quantized to this many ticks.
  static const _scrambleFrames = 20;

  @override
  void initState() {
    super.initState();
    _scheduleDwell();
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _glitch.dispose();
    super.dispose();
  }

  void _scheduleDwell() {
    if (widget.texts.length < 2) {
      return;
    }
    final jitterMs = widget.dwellJitter.inMilliseconds;
    final extra = jitterMs > 0 ? _random.nextInt(jitterMs + 1) : 0;
    _dwellTimer = Timer(
      widget.baseDwell + Duration(milliseconds: extra),
      _beginGlitch,
    );
  }

  void _beginGlitch() {
    if (!mounted) {
      return;
    }
    setState(() {
      _glitching = true;
      _pendingIndex = pickNextGlitchIndex(
        _index,
        widget.texts.length,
        _random,
      );
    });
    _glitch.forward(from: 0);
  }

  void _onGlitchStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    setState(() {
      _glitching = false;
      _index = _pendingIndex;
    });
    _scheduleDwell();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.texts.isEmpty) {
      return const SizedBox.shrink();
    }
    // The style is used AS-IS for the primary layer — including any shadow
    // the caller baked in (e.g. the player-selection title's blue glow).
    // The default carries its own single tight white glow. ONE shadow max
    // on huge display text (I-056).
    final baseStyle = widget.style ??
        (Theme.of(context).textTheme.displaySmall ??
                const TextStyle(fontSize: 45))
            .copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 10,
            ),
          ],
        );
    // Effect layers never inherit the shadow — three blurred copies of huge
    // text is exactly the SwiftShader frame-drop pattern I-056 warns about.
    final splitStyle = baseStyle.copyWith(shadows: const []);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedBuilder(
          animation: _glitch,
          builder: (context, child) {
            final progress = _glitching ? _glitch.value : 0.0;
            final firstHalf = progress < 0.5;
            final base = widget.texts[firstHalf ? _index : _pendingIndex];
            final intensity = progress <= 0 || progress >= 1
                ? 0.0
                : (firstHalf ? progress * 2 : (1 - progress) * 2);
            final tick = (progress * _scrambleFrames).floor();
            final display = scrambleGlitchText(
              base,
              intensity: intensity,
              tick: tick,
            );
            if (intensity <= 0) {
              return Text(
                display,
                style: baseStyle,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
              );
            }
            // Glitching: RGB-split offset layers behind the primary text.
            // intensity is in (0, 1] here, so no clamping is needed.
            final layerOpacity = 0.85 * intensity;
            final dx = 8.0 * intensity;
            final dirA = _glitchHash(1, tick).isEven ? 1.0 : -1.0;
            final dirB = _glitchHash(2, tick).isEven ? 1.0 : -1.0;
            return Transform.translate(
              offset: Offset(0, 2.0 * intensity * dirB),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(-dx * dirA, 0),
                    child: Opacity(
                      opacity: layerOpacity,
                      child: Text(
                        display,
                        style: splitStyle.copyWith(
                          color: const Color(0xFFFF2D78),
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(dx * dirB, 0),
                    child: Opacity(
                      opacity: layerOpacity,
                      child: Text(
                        display,
                        style: splitStyle.copyWith(
                          color: const Color(0xFF25F4EE),
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  Text(
                    display,
                    style: baseStyle,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
