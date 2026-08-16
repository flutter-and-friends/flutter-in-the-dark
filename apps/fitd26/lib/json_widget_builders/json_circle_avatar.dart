import 'package:json_dynamic_widget/json_dynamic_widget.dart';

part 'json_circle_avatar.g.dart';

@jsonWidget
abstract class _JsonCircleAvatarBuilder extends JsonWidgetBuilder {
  const _JsonCircleAvatarBuilder({required super.args});

  @override
  CircleAvatar buildCustom({
    ChildWidgetBuilder? childBuilder,
    required BuildContext context,
    required JsonWidgetData data,
    Key? key,
  });
}
