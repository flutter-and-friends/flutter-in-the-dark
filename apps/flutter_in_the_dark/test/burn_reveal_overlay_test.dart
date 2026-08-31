import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'burn_reveal_test_harness.dart';

/// Regression tests for the challenger-screen blocking-countdown bug: the
/// end-of-challenge countdown/burn overlay used to wrap itself in
/// PointerInterceptor + AbsorbPointer for the WHOLE 10 s countdown gate,
/// visually blocking the player's prompt field while the challenge was
/// still live. The gate is now split from visibility: the countdown is
/// VISIBLE-but-non-blocking while the challenge is live, and blocks only
/// from the burn window (the last ~1 s, spanning the zero crossing).
///
/// The controller under test is the mirror harness (burn_reveal_test_
/// harness.dart) — the real one transitively imports package:web (W-012).
/// Timing is driven by TICKING the controller with pumped wall-clock steps,
/// never by a Timer.periodic — fake-async starves periodic timers (I-017).
void main() {
  setUp(BurnDebug.reset);

  /// The minimal shell the real overlay now uses over the live UI: an
  /// IgnorePointer + AbsorbPointer overlay stacked over the text field,
  /// exactly the Stack composition of the challenge screen (overlay after
  /// the Scaffold in the Stack, so it is on top).
  Widget overlayShell({required bool blocking}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const TextField(),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !blocking,
                child: AbsorbPointer(
                  absorbing: blocking,
                  child: ColoredBox(
                    key: const ValueKey('overlay'),
                    color: blocking ? Colors.black : Colors.black38,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  group('blocking gate (phase machine)', () {
    testWidgets('non-blocking while the challenge is live, blocking from the '
        'burn window, revealed at zero', (tester) async {
      final controller = BurnRevealController(vsync: tester);
      addTearDown(controller.dispose);

      controller.tick(const Duration(seconds: 30));
      expect(controller.isCountingDown, isFalse);
      expect(controller.isBlocking, isFalse);

      // Inside the 10 s countdown gate: visible, NOT blocking.
      controller.tick(const Duration(seconds: 10));
      expect(controller.isCountingDown, isTrue);
      expect(
        controller.isBlocking,
        isFalse,
        reason: 'the challenge is still live — the player must keep typing',
      );

      controller.tick(const Duration(seconds: 5));
      expect(controller.isBlocking, isFalse);

      // Just above the burn window: still live, still non-blocking.
      controller.tick(const Duration(milliseconds: 1500));
      expect(controller.isBlocking, isFalse);

      // The burn window: the overlay turns blocking.
      controller.tick(const Duration(milliseconds: 500));
      expect(
        controller.isBlocking,
        isTrue,
        reason: 'the burn spans the zero crossing — the challenge is over',
      );

      // At zero the burn snaps to done and the overlay is gone for good.
      controller.tick(Duration.zero);
      expect(controller.isRevealed, isTrue);
      expect(controller.isBlocking, isFalse);
    });

    testWidgets('a first paint inside the countdown never blocks before the '
        'burn window', (tester) async {
      final controller = BurnRevealController(vsync: tester);
      addTearDown(controller.dispose);

      controller.tick(const Duration(seconds: 8));
      expect(controller.isCountingDown, isTrue);
      expect(controller.isBlocking, isFalse);
    });

    testWidgets('a jump straight past the window (backgrounded tab, W-017) '
        'snaps to revealed without a blocking interval', (tester) async {
      final controller = BurnRevealController(vsync: tester);
      addTearDown(controller.dispose);

      controller.tick(const Duration(seconds: -1));
      expect(controller.isRevealed, isTrue);
      expect(controller.isBlocking, isFalse);
    });

    testWidgets('burn progress tracks the pumped wall clock through the '
        'window', (tester) async {
      final controller = BurnRevealController(vsync: tester);
      addTearDown(controller.dispose);

      controller.tick(const Duration(seconds: 10));
      expect(controller.burn, isNotNull);

      // 1 s window, stepped in 100 ms pumped ticks (I-017: small steps).
      for (var i = 9; i >= 1; i--) {
        controller.tick(Duration(milliseconds: i * 100));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final progress = controller.burn!.value;
      expect(progress, greaterThan(0.0));
      expect(progress, lessThanOrEqualTo(1.0));
      expect(
        progress,
        closeTo(0.9, 0.05),
        reason: 'wall-clock progress after 900 ms of a 1 s window',
      );

      controller.tick(Duration.zero);
      expect(controller.burn!.value, 1.0);
      expect(controller.isRevealed, isTrue);
    });
  });

  group('debug knobs', () {
    testWidgets('?burnSeconds moves the burn (and the blocking gate) off '
        'the wall-clock end', (tester) async {
      BurnDebug.burnSeconds = 5;
      final controller = BurnRevealController(vsync: tester);
      addTearDown(controller.dispose);

      // The burn window is now 5→4 s: the countdown is non-blocking before
      // it (the challenge is live), blocking from its start.
      controller.tick(const Duration(seconds: 10));
      expect(controller.isCountingDown, isTrue);
      expect(controller.isBlocking, isFalse);

      controller.tick(const Duration(milliseconds: 5500));
      expect(controller.isBlocking, isFalse);

      controller.tick(const Duration(milliseconds: 4500));
      expect(
        controller.isBlocking,
        isTrue,
        reason: 'inside the steered burn window the overlay blocks',
      );
      expect(controller.burn!.value, greaterThan(0.0));

      // A jump straight past the (steered) window still snaps to revealed —
      // the zero guard is window-agnostic.
      controller.tick(Duration.zero);
      expect(controller.isRevealed, isTrue);
    });

    testWidgets('?burnHold holds the burn — and the block — indefinitely', (
      tester,
    ) async {
      BurnDebug.holdAt = 0.5;
      final controller = BurnRevealController(vsync: tester);
      addTearDown(controller.dispose);

      controller.tick(const Duration(seconds: 30));
      expect(controller.isCountingDown, isTrue);
      expect(
        controller.isBlocking,
        isTrue,
        reason: 'a held burn is the blocking window by definition',
      );
      expect(controller.burn!.value, 0.5);
      expect(controller.isRevealed, isFalse);
    });
  });

  group('non-blocking shell (overlay shape while live)', () {
    testWidgets('the text field underneath keeps focus and accepts input '
        'through the visible overlay', (tester) async {
      await tester.pumpWidget(overlayShell(blocking: false));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'still typing');
      expect(find.text('still typing'), findsOneWidget);
    });

    testWidgets('the same shell blocks the field once the burn window is up',
        (tester) async {
      await tester.pumpWidget(overlayShell(blocking: true));

      // Tap on the overlay-covered area; the field must NOT take focus.
      await tester.tap(find.byKey(const ValueKey('overlay')));
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isFalse);
    });
  });
}
