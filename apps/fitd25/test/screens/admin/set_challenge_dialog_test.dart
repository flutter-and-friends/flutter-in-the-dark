import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fitd25/screens/admin/set_challenge_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SetChallengeDialog', () {
    final initialDate = DateTime(2025, 1, 1, 12, 0, 0);

    Future<dynamic> pumpDialog(WidgetTester tester) async {
      dynamic result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog(
                    context: context,
                    builder: (context) =>
                        SetChallengeDialog(initialDate: initialDate),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('shows initial values and can be updated', (tester) async {
      await pumpDialog(tester);

      // Verify initial state
      expect(
        find.text('Start: ${initialDate.toIso8601String()}'),
        findsOneWidget,
      );
      expect(find.text('Duration: 5 minutes'), findsOneWidget);

      // Test duration buttons
      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();
      expect(find.text('Duration: 15 minutes'), findsOneWidget);
    });

    testWidgets('sets start time to 10 seconds in the future', (tester) async {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      await withClock(Clock.fixed(now), () async {
        final getResult = await pumpDialog(tester);

        // Test "In 10 seconds" button
        await tester.tap(find.text('In 10 seconds'));
        await tester.pumpAndSettle();
        expect(
          find.text('Starts 10 seconds after pressing OK'),
          findsOneWidget,
        );

        // Test OK button with "In 10 seconds"
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.byType(SetChallengeDialog), findsNothing);
        final result = getResult();
        expect(result, isA<Map<String, DateTime>>());
        expect(result['startTime'], now.add(const Duration(seconds: 10)));
      });
    });

    testWidgets('can manually set date and time', (tester) async {
      final newDate = DateTime(2025, 1, 2, 14, 30);
      final getResult = await pumpDialog(tester);

      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      // Date picker
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('2'));
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();

      // Time picker
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();

      // Back in the main dialog
      expect(find.byType(SetChallengeDialog), findsOneWidget);
      final expectedDate = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        initialDate.hour,
        initialDate.minute,
      );
      expect(
        find.text('Start: ${expectedDate.toIso8601String()}'),
        findsOneWidget,
      );
    });

    testWidgets('can set time to now', (tester) async {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      await withClock(Clock.fixed(now), () async {
        final getResult = await pumpDialog(tester);

        await tester.tap(find.text('Now'));
        await tester.pumpAndSettle();

        expect(find.text('Starts 0 seconds after pressing OK'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final result = getResult();
        expect(result['startTime'], now);
      });
    });

    testWidgets('returns values when OK is pressed', (tester) async {
      final getResult = await pumpDialog(tester);

      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final result = getResult();
      expect(result, isA<Map<String, DateTime>>());
      expect(result['startTime'], initialDate);
      expect(result['endTime'], initialDate.add(const Duration(minutes: 15)));
    });

    testWidgets('returns null when Cancel is pressed', (tester) async {
      final getResult = await pumpDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(getResult(), isNull);
    });

    testWidgets('elapse time with fake_async', (tester) async {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      dynamic result;

      await fakeAsync((async) async {
        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      result = await showDialog(
                        context: context,
                        builder: (context) =>
                            SetChallengeDialog(initialDate: initialDate),
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Show Dialog'));
          await tester.pumpAndSettle();

          // Test "In 10 seconds" button
          await tester.tap(find.text('In 10 seconds'));
          await tester.pumpAndSettle();

          expect(
            find.text('Starts 10 seconds after pressing OK'),
            findsOneWidget,
          );

          // Simulate a 5-second delay
          async.elapse(const Duration(seconds: 5));

          // Test OK button with "In 10 seconds"
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
        });
      });

      expect(find.byType(SetChallengeDialog), findsNothing);
      expect(result, isA<Map<String, DateTime>>());
      // The clock is advanced by 5s inside fakeAsync, so the final time should be 15s after now.
      expect(result['startTime'], now.add(const Duration(seconds: 15)));
    });
  });
}