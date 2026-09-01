/// Pure burn steering-knob parsing — the SINGLE parser both consumers use
/// (SHADOW-005: the knob contract used to be parsed twice, `BurnDebug` via
/// RegExp on `window.location` in `widgets/burn_reveal.dart` and
/// `BurnTestKnobs` via `Uri.queryParameters` in
/// `screens/burn_test_screen.dart`, and they could drift). Kept free of
/// Flutter and `dart:js_interop` imports so it is unit-testable on the VM
/// (W-012).
///
/// The knobs (debug/steering only — never wired to real UI):
///  - `burnSlow=<x>` multiplies the burn duration (e.g. `burnSlow=5`),
///  - `burnHold=<0..1>` freezes the burn at exactly that progress,
///  - `burnDebug=1` shows the replay button on the production overlay,
///  - `burnMode=mask|shader` picks the renderer on `/burn_test` (A/B),
///  - `burnSeconds=<x>` moves the burn window (and thus the pointer-block
///    gate) off the wall-clock end — e.g. `burnSeconds=15` burns 15→14 s so
///    the last 14 s of a challenge can be verified LIVE under the countdown.
library;

/// Which burn implementation `/burn_test` renders (burn-perf A/B).
enum BurnMode { mask, shader }

/// The parsed steering knobs shared by the production overlay and `/burn_test`.
class BurnKnobs {
  const BurnKnobs({
    this.slowFactor = 1,
    this.holdAt,
    this.debug = false,
    this.mode = BurnMode.shader,
    this.burnSeconds,
  });

  /// Multiplier on the burn duration (`?burnSlow=5` → 5× slower).
  final double slowFactor;

  /// When non-null the burn is held at exactly this progress (0–1) and the
  /// countdown → reveal handoff is suspended. Debug-only.
  final double? holdAt;

  /// `?burnDebug=1` — shows the replay button on the production overlay.
  final bool debug;

  /// Which renderer `/burn_test` uses. Production always uses the shader;
  /// this knob only affects the A/B page.
  final BurnMode mode;

  /// Debug-only (`?burnSeconds=<x>`): overrides the burn window's position
  /// on the countdown. Null (the default) anchors the burn to the last
  /// [kBurnSeconds] before zero, as before; a value ≥ the countdown gate
  /// (`kCountdownSeconds`) burns EARLY so the non-blocking-countdown
  /// behavior can be steered/verified on a live challenge without touching
  /// the server clock. Note the overlay stays BLOCKING from the steered
  /// burn to the wall-clock end (the controller cannot know the early burn
  /// was a knob rather than the real end) — for a truly-live-after view
  /// pair it with a fresh window (query change ⇒ reload ⇒ new controller).
  /// Ignored by `/burn_test` (which drives progress directly).
  final double? burnSeconds;

  /// Parses the knobs from a query string (`?burnSlow=5&burnHold=0.5`) or
  /// a full route/URL — anything [Uri.parse] accepts. Unknown/missing
  /// values fall back to the defaults.
  factory BurnKnobs.parse(String? queryOrUri) {
    // Tolerate BOTH a full route/URL and a bare query string. `Uri.parse`
    // treats a leading '?...' as a path with no query, so normalize that
    // shape (production passes `window.location.search`, which starts with
    // '?').
    var input = queryOrUri ?? '';
    if (input.startsWith('?')) input = '/$input';
    final query = Uri.parse(input).queryParameters;
    return BurnKnobs(
      slowFactor: _slow(query),
      holdAt: _hold(query),
      debug: query['burnDebug'] == '1',
      mode: query['burnMode'] == 'mask' ? BurnMode.mask : BurnMode.shader,
      burnSeconds: _burnSeconds(query),
    );
  }

  static double _slow(Map<String, String> query) {
    final value = double.tryParse(query['burnSlow'] ?? '');
    if (value == null || value <= 0) return 1;
    return value;
  }

  static double? _hold(Map<String, String> query) {
    final value = double.tryParse(query['burnHold'] ?? '');
    return value?.clamp(0.0, 1.0);
  }

  static double? _burnSeconds(Map<String, String> query) {
    final value = double.tryParse(query['burnSeconds'] ?? '');
    if (value == null || value <= 0) return null;
    return value;
  }
}
