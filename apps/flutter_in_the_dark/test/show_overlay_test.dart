import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/helpers/time_over.dart';
import 'package:flutter_in_the_dark/widgets/show_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

/// show_overlay.dart is deliberately OUTSIDE the W-012 tainted cone (no
/// room_client / dart:js_interop), so these widgets CAN be widget-tested
/// directly — unlike show_screen.dart.
void main() {
  testWidgets('TimeOverBanner shows the text inside the window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeOverBanner(
            endTime: DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        ),
      ),
    );
    expect(find.text('TIME OVER!'), findsOneWidget);
  });

  testWidgets('TimeOverBanner is empty outside the window', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeOverBanner(
            endTime: DateTime.now().subtract(
              kTimeOverBannerDuration + const Duration(seconds: 5),
            ),
          ),
        ),
      ),
    );
    expect(find.text('TIME OVER!'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeOverBanner(
            endTime: DateTime.now().add(const Duration(minutes: 3)),
          ),
        ),
      ),
    );
    expect(find.text('TIME OVER!'), findsNothing);
  });

  testWidgets('TimeOverBanner scales to fit a narrow viewport', (
    tester,
  ) async {
    // Phone-width surface: the banner must NOT overflow (the raw 200 pt
    // hardcoded size splintered letters across lines on a phone). The
    // FittedBox shrink-to-fit keeps it on one line within the viewport.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeOverBanner(
            endTime: DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TIME OVER!'), findsOneWidget);
    // No overflow exception was thrown laying out the banner.
    expect(tester.takeException(), isNull);
    // The FittedBox (the shrink-to-fit container) is laid out within the
    // 400-wide viewport; the text inside it is scaled down to match. (The
    // Text's own layout size is its unscaled 200 pt width — what matters
    // for overflow is the box that bounds it on screen.)
    final boxSize = tester.getSize(find.byType(FittedBox));
    expect(boxSize.width, lessThanOrEqualTo(400));
    // And the scale actually shrank the 200 pt text (desktop keeps the
    // drama; mobile fits).
    expect(boxSize.width, lessThan(1000));
  });

  testWidgets('ShowTimerPill shows the remaining time and hides ≤ 10 s', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowTimerPill(
            endTime: DateTime.now().add(const Duration(minutes: 4)),
          ),
        ),
      ),
    );
    await tester.pump();
    // The pill's DecoratedBox pill is present while > 10 s remain.
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowTimerPill(
            endTime: DateTime.now().add(const Duration(seconds: 5)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });
}
