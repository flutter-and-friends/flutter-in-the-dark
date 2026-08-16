import 'package:json_dynamic_widget/json_dynamic_widget.dart';

part 'json_choice_chip.g.dart';

@jsonWidget
abstract class _JsonChoiceChipBuilder extends JsonWidgetBuilder {
  const _JsonChoiceChipBuilder({required super.args});

  @override
  ChoiceChip buildCustom({
    ChildWidgetBuilder? childBuilder,
    required BuildContext context,
    required JsonWidgetData data,
    Key? key,
  });
}
