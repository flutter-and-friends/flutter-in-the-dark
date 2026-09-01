/// Pure burn-reveal phase computation — deliberately kept free of Flutter
/// imports so it is unit-testable on the Dart VM (W-012: the widgets that
/// consume this import `compiled_widget.dart` → `dart:js_interop` and cannot
/// be widget-tested). Used by `lib/widgets/burn_reveal.dart`.
library;

/// Result of sampling the burn animation at progress [p] ∈ [0, 1].
typedef BurnSample = ({
  /// Radius of the charred (fully transparent) hole center, as a fraction
  /// of the overlay's center-to-corner distance.
  double holeRadius,

  /// Outer radius of the charred (darkened) ring, same units.
  double charRadius,

  /// Outer radius of the glowing flame rim, same units.
  double flameRadius,

  /// Opacity of the flame rim (ramps in early, fades out late).
  double rimAlpha,
});

/// Result of sampling the burn at progress [p] AND polar angle [theta]
/// (radians, from the burn center) — the jagged form of [BurnSample]. The
/// radii vary with angle (a real paper burn is not a circle); [rimAlpha]
/// is angularly uniform.
typedef BurnSampleAt = ({
  /// Perturbed hole radius (fully transparent center), fraction of the
  /// overlay's center-to-corner distance.
  double holeRadius,

  /// Perturbed outer radius of the charred ring, same units.
  double charRadius,

  /// Perturbed outer radius of the flame rim, same units.
  double flameRadius,

  /// Opacity of the flame rim (same as [BurnSample.rimAlpha]).
  double rimAlpha,
});

/// Total burn-window share of a countdown that STARTS at exactly
/// [kCountdownSeconds] seconds (the 10→0 gate). Below a full second of
/// countdown the burn is shortened ([burnWindowFor]) so the transition never
/// takes longer than the countdown itself.
const double kBurnSeconds = 1.0;

/// The countdown gate used by the waiting / end-of-challenge overlays: the
/// big 10→0 countdown appears when the remaining time drops to this many
/// seconds.
const int kCountdownSeconds = 10;

/// The end-of-challenge blocking gate: until the remaining time drops to
/// this many seconds the overlay must stay NON-blocking — the challenge is
/// still live and the player must be able to keep typing underneath the
/// countdown. At/below it (the burn window, whose tail crosses zero), the
/// challenge is over and the overlay blocks like the waiting gate.
const double kBlockingSeconds = kBurnSeconds;

/// Whether the burn should be playing at [remaining] seconds left.
bool isBurning(double remaining) => remaining <= kBurnSeconds && remaining > 0;

/// Animation progress (0 = just ignited, 1 = countdown over → overlay gone)
/// at [remaining] seconds left. Callers only invoke this while
/// [isBurning] is true; out-of-range inputs are clamped.
double burnProgress(double remaining) =>
    1.0 - (remaining / kBurnSeconds).clamp(0.0, 1.0);

/// Burn duration when the countdown starts at [remainingStart] seconds left.
/// An admin can start a challenge with < 10 s of delay (or a client can
/// first paint mid-countdown); in those cases the burn is shortened so it
/// never exceeds the countdown itself.
Duration burnWindowFor(double remainingStart) {
  final seconds = remainingStart < kBurnSeconds ? remainingStart : kBurnSeconds;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// Radius of the frame diagonal's center-to-corner half, given a frame of
/// [maxRadius] units. Callers pass the actual half-diagonal; this exists so
/// tests pin the normalization convention: radii are fractions of the
/// center-to-corner distance, so the hole reaches the corners exactly at
/// p = 1.
double normalizedCorner(double halfDiagonal) => halfDiagonal;

/// Samples the burn at progress [p] (clamped to [0, 1]).
///
/// Shape (fractions of the center-to-corner distance):
///  - the charred hole opens immediately and accelerates outward
///    (`easeInCubic`, reaching 1.0 exactly at p = 1),
///  - the flame rim rides just outside the charred edge,
///  - the rim fades in fast (first 15 %) so ignition is visible, and fades
///    out over the last 25 % as the hole consumes the frame.
BurnSample sampleBurn(double p) {
  final t = p.clamp(0.0, 1.0);
  final hole = _easeInCubic(t);
  final char = (hole + 0.10).clamp(0.0, 1.3);
  final flame = (hole + 0.18).clamp(0.0, 1.5);
  final fadeIn = (t / 0.15).clamp(0.0, 1.0);
  final fadeOut = t <= 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
  return (
    holeRadius: hole,
    charRadius: char,
    flameRadius: flame,
    rimAlpha: fadeIn * fadeOut,
  );
}

/// Samples the burn at progress [p] and polar angle [theta], perturbing
/// the radii by [radiusScale] (see `BurnEdge.radiusScaleAt` in
/// `burn_edge.dart`).
///
/// Band structure is preserved per-angle: the base hole radius is scaled,
/// then the SAME angularly-varying absolute widths are added on top
/// (`charWidth = baseChar − baseHole`, scaled by the angular scale). Char
/// therefore hugs the hole and the flame hugs the char along the jagged
/// contour everywhere, and the bands never collapse or cross at the
/// inward spikes (a scaled constant width can vanish where the scale
/// dips). At p = 1 the overlay is dropped by the caller exactly as before,
/// so the perturbed hole radius never needs to cover the corners.
BurnSampleAt sampleBurnAt(
  double p,
  double theta,
  double Function(double theta) radiusScale,
) {
  final base = sampleBurn(p);
  final scale = radiusScale(theta);
  final hole = base.holeRadius * scale;
  final charWidth = (base.charRadius - base.holeRadius) * scale;
  final flameWidth = (base.flameRadius - base.charRadius) * scale;
  return (
    holeRadius: hole,
    charRadius: hole + charWidth,
    flameRadius: hole + charWidth + flameWidth,
    rimAlpha: base.rimAlpha,
  );
}

double _easeInCubic(double t) => t * t * t;
