import 'package:flutter_in_the_dark/helpers/time_over.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowTimeOver', () {
    test('hidden while the challenge is still live', () {
      expect(shouldShowTimeOver(const Duration(minutes: 4)), isFalse);
      expect(shouldShowTimeOver(const Duration(seconds: 1)), isFalse);
      expect(shouldShowTimeOver(Duration.zero), isTrue);
    });

    test('visible exactly at the zero crossing and inside the window', () {
      expect(shouldShowTimeOver(const Duration(milliseconds: -1)), isTrue);
      expect(shouldShowTimeOver(const Duration(seconds: -2)), isTrue);
      // The last instant of the window still shows (boundary is exclusive
      // below, so a tick at exactly -5 s is the first hidden frame).
      expect(
        shouldShowTimeOver(
          -kTimeOverBannerDuration + const Duration(milliseconds: 1),
        ),
        isTrue,
      );
    });

    test('auto-dismisses after the banner duration', () {
      expect(shouldShowTimeOver(-kTimeOverBannerDuration), isFalse);
      expect(
        shouldShowTimeOver(
            -kTimeOverBannerDuration - const Duration(seconds: 1)),
        isFalse,
      );
      // A challenge that has been over for minutes must not re-show the
      // banner on a late rebuild.
      expect(shouldShowTimeOver(const Duration(minutes: -30)), isFalse);
    });
  });
}
