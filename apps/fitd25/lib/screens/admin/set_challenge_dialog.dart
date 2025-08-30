import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

class SetChallengeDialog extends StatefulWidget {
  const SetChallengeDialog({super.key});

  @override
  State<SetChallengeDialog> createState() => _SetChallengeDialogState();
}

class _SetChallengeDialogState extends State<SetChallengeDialog> {
  late Duration _duration;
  late Duration _startFromNowDuration;

  @override
  void initState() {
    super.initState();
    _startFromNowDuration = const Duration(seconds: 15);
    _duration = const Duration(minutes: 10);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Challenge Times'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Starts ${_startFromNowDuration.inSeconds} seconds after pressing OK',
          ),
          const SizedBox(height: 10),
          Text('Duration: ${_duration.inMinutes} minutes'),
          const SizedBox(height: 20),
          const Text('Set Start Time'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ElevatedButton(
              //   onPressed: () async {
              //     final newStartTime = await _selectDateTime(_startTime);
              //     if (newStartTime != null) {
              //       setState(() {
              //         _startTime = newStartTime;
              //         _startFromNowDuration = null;
              //       });
              //     }
              //   },
              //   child: const Text('Manual'),
              // ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _startFromNowDuration = const Duration(seconds: 10);
                  });
                },
                child: const Text('In 10 seconds'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _startFromNowDuration = const Duration(seconds: 15);
                  });
                },
                child: const Text('In 15 seconds'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _startFromNowDuration = Duration.zero;
                  });
                },
                child: const Text('Now'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Set Duration'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () =>
                    setState(() => _duration = const Duration(minutes: 5)),
                child: const Text('5 min'),
              ),
              ElevatedButton(
                onPressed: () =>
                    setState(() => _duration = const Duration(minutes: 10)),
                child: const Text('10 min'),
              ),
              ElevatedButton(
                onPressed: () =>
                    setState(() => _duration = const Duration(minutes: 15)),
                child: const Text('15 min'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final finalStartTime = clock.now().add(_startFromNowDuration);
            Navigator.of(context).pop({
              'startTime': finalStartTime,
              'endTime': finalStartTime.add(_duration),
            });
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Future<DateTime?> _selectDateTime(DateTime initialDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate.subtract(const Duration(days: 30)),
      lastDate: initialDate.add(const Duration(days: 365)),
    );
    if (date == null) return null;

    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
