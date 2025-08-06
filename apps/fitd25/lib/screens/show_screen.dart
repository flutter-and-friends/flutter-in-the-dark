import 'package:fitd25/data/challenge.dart';
import 'package:fitd25/widgets/countdown_overlay.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  late final JsonWidgetData jsonWidgetData;

  @override
  void initState() {
    jsonWidgetData = JsonWidgetData.fromDynamic(widget.challenge.widgetJson);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.challenge.name)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          jsonWidgetData.build(context: context),
          Positioned(
            top: 50,
            child: Timeago(
              refreshRate: const Duration(milliseconds: 100),
              date: widget.challenge.endTime,
              allowFromNow: true,
              builder: (context, time) {
                final remainingTime = widget.challenge.endTime.difference(
                  DateTime.now(),
                );
                if (remainingTime.isNegative) {
                  return const Text(
                    'Time over!',
                    style: TextStyle(fontSize: 48, color: Colors.red),
                  );
                }

                if (remainingTime.inSeconds > 10) {
                  return Text(
                    'Time remaining: $time',
                    style: TextStyle(
                      fontSize: 48,
                      backgroundColor: Colors.black54,
                      color: Colors.white,
                    ),
                  );
                }

                return Container();
              },
            ),
          ),
          Timeago(
            refreshRate: const Duration(milliseconds: 100),
            date: widget.challenge.endTime,
            allowFromNow: true,
            builder: (context, time) {
              final remainingTime = widget.challenge.endTime.difference(
                DateTime.now(),
              );

              if (remainingTime.isNegative || remainingTime.inSeconds > 10) {
                return Container();
              }

              return CountdownOverlay(duration: remainingTime);
            },
          ),
        ],
      ),
    );
  }
}
