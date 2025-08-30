import 'package:fitd25/json_widget_builders/json_choice_chip.dart';
import 'package:fitd25/json_widget_builders/json_circle_avatar.dart';
import 'package:fitd25/json_widget_builders/json_image_network_builder.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';

abstract class AllJsonWidgetBuildersRegistrar {}

class AllJsonWidgetBuilders {
  const AllJsonWidgetBuilders._();

  static void register() {
    JsonWidgetRegistry.instance.registerCustomBuilders({
      JsonImageNetworkBuilder.kType: const JsonWidgetBuilderContainer(
        builder: JsonImageNetworkBuilder.fromDynamic,
      ),
      JsonCircleAvatarBuilder.kType: const JsonWidgetBuilderContainer(
        builder: JsonCircleAvatarBuilder.fromDynamic,
      ),
      JsonChoiceChipBuilder.kType: const JsonWidgetBuilderContainer(
        builder: JsonChoiceChipBuilder.fromDynamic,
      ),
    });
  }
}
