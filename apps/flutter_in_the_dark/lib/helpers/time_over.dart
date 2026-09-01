/// Pure timing helpers for the /show projector "Time over!" banner —
/// deliberately free of Flutter imports so it is unit-testable on the Dart
/// VM (W-012: the consuming `show_screen.dart` transitively imports
/// `room_client.dart` → `dart:js_interop` and cannot be widget-tested).
///
/// The banner pops BIG for a few seconds at end-of-challenge, then
/// auto-dismisses so the finished content underneath is readable again.
/// It is driven by the host screen's wall-clock ticker (a Timer feeding
/// this function), NEVER by a bare `DateTime.now()` gate in `build`
/// (I-008: such a gate is not self-updating).
library;

/// How long the "Time over!" banner stays up after the challenge ends.
const Duration kTimeOverBannerDuration = Duration(seconds: 5);

/// Whether the "Time over!" banner should be visible at [remaining]
/// (endTime − now). True for exactly the window
/// `(−kTimeOverBannerDuration, 0]`: the moment the clock crosses zero the
/// banner pops; [kTimeOverBannerDuration] later it goes away on its own.
///
/// Edge semantics: [remaining] == Duration.zero (or the smallest positive
/// sliver after crossing) counts as just-ended; anything ≤ the negative
/// duration has aged out. A challenge that has been over for minutes must
/// not re-show the banner on a late rebuild.
bool shouldShowTimeOver(Duration remaining) =>
    remaining <= Duration.zero && remaining > -kTimeOverBannerDuration;
