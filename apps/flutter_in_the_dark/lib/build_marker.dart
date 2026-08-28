/// Build marker: git short hash + build timestamp, baked in at build time via
///
///   flutter build web \
///     --dart-define=GIT_HASH=$(git rev-parse --short HEAD) \
///     --dart-define=BUILD_TIME=$(date -u +%Y-%m-%dT%H:%MZ)
///
/// Exists so a human can tell at a glance whether a page reload actually
/// picked up the newest deployed build (deploy-cache trap): every screen
/// logs it to the browser console on startup, and the admin screen shows it
/// as a small chip.
///
/// NOTE: an EMPTY dart-define does NOT mean "unset" —
/// `String.fromEnvironment` cannot distinguish "set to empty" from "unset",
/// so the marker treats empty the same as missing and falls back to `dev`
/// (the local `flutter run` path, where the defines are absent).
const String _gitHash = String.fromEnvironment('GIT_HASH');
const String _buildTime = String.fromEnvironment('BUILD_TIME');

/// Effective git short hash, or `'dev'` when the define is absent/empty.
String get buildGitHash => _gitHash.isEmpty ? 'dev' : _gitHash;

/// Effective build timestamp, or `'local'` when the define is absent/empty.
String get buildTime => _buildTime.isEmpty ? 'local' : _buildTime;

/// One-line marker, e.g. `FITD build a1b2c3d · 2026-08-28 14:32Z`
/// (`FITD build dev · local` on an un-flagged local run).
String get buildMarker => 'FITD build $buildGitHash · $buildTime';

/// Prints the marker to the browser console. Uses bare `print` (→
/// `console.log`) rather than `debugPrint` (→ `console.debug`): Chrome's
/// console hides `console.debug` unless Verbose is enabled, and the marker
/// exists precisely to be SEEN on a casual F12. Called once from `main()`
/// so every route logs it.
// ignore_for_file: avoid_print
void logBuildMarker() {
  print(buildMarker);
}
