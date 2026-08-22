import 'package:timeago_flutter/timeago_flutter.dart';

class OverrideEnTimeAgo extends EnMessages {
  @override
  String suffixFromNow() => '';

  @override
  String suffixAgo() => '';

  @override
  String lessThanOneMinute(int seconds) => '$seconds seconds';
}
