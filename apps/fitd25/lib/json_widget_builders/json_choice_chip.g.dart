// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_choice_chip.dart';

// **************************************************************************
// Generator: JsonWidgetLibraryBuilder
// **************************************************************************

// ignore_for_file: avoid_init_to_null
// ignore_for_file: deprecated_member_use

// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_constructors_in_immutables
// ignore_for_file: prefer_final_locals
// ignore_for_file: prefer_if_null_operators
// ignore_for_file: prefer_single_quotes
// ignore_for_file: unused_local_variable

class JsonChoiceChipBuilder extends _JsonChoiceChipBuilder {
  const JsonChoiceChipBuilder({required super.args});

  static const kType = 'choice_chip';

  /// Constant that can be referenced for the builder's type.
  @override
  String get type => kType;

  /// Static function that is capable of decoding the widget from a dynamic JSON
  /// or YAML set of values.
  static JsonChoiceChipBuilder fromDynamic(
    dynamic map, {
    JsonWidgetRegistry? registry,
  }) => JsonChoiceChipBuilder(args: map);

  @override
  JsonChoiceChipBuilderModel createModel({
    ChildWidgetBuilder? childBuilder,
    required JsonWidgetData data,
  }) {
    final model = JsonChoiceChipBuilderModel.fromDynamic(
      args,
      registry: data.jsonWidgetRegistry,
    );

    return model;
  }

  @override
  ChoiceChip buildCustom({
    ChildWidgetBuilder? childBuilder,
    required BuildContext context,
    required JsonWidgetData data,
    Key? key,
  }) {
    final model = createModel(childBuilder: childBuilder, data: data);

    return ChoiceChip(
      autofocus: model.autofocus,
      avatar: model.avatar?.build(childBuilder: childBuilder, context: context),
      avatarBorder: model.avatarBorder,
      avatarBoxConstraints: model.avatarBoxConstraints,
      backgroundColor: model.backgroundColor,
      checkmarkColor: model.checkmarkColor,
      chipAnimationStyle: model.chipAnimationStyle,
      clipBehavior: model.clipBehavior,
      color: model.color,
      disabledColor: model.disabledColor,
      elevation: model.elevation,
      focusNode: model.focusNode,
      iconTheme: model.iconTheme,
      key: key,
      label: model.label.build(childBuilder: childBuilder, context: context),
      labelPadding: model.labelPadding,
      labelStyle: model.labelStyle,
      materialTapTargetSize: model.materialTapTargetSize,
      mouseCursor: model.mouseCursor,
      onSelected: model.onSelected,
      padding: model.padding,
      pressElevation: model.pressElevation,
      selected: model.selected,
      selectedColor: model.selectedColor,
      selectedShadowColor: model.selectedShadowColor,
      shadowColor: model.shadowColor,
      shape: model.shape,
      showCheckmark: model.showCheckmark,
      side: model.side,
      surfaceTintColor: model.surfaceTintColor,
      tooltip: model.tooltip,
      visualDensity: model.visualDensity,
    );
  }
}

class JsonChoiceChip extends JsonWidgetData {
  JsonChoiceChip({
    Map<String, dynamic> args = const {},
    JsonWidgetRegistry? registry,
    this.autofocus = false,
    this.avatar,
    this.avatarBorder = const CircleBorder(),
    this.avatarBoxConstraints,
    this.backgroundColor,
    this.checkmarkColor,
    this.chipAnimationStyle,
    this.clipBehavior = Clip.none,
    this.color,
    this.disabledColor,
    this.elevation,
    this.focusNode,
    this.iconTheme,
    required this.label,
    this.labelPadding,
    this.labelStyle,
    this.materialTapTargetSize,
    this.mouseCursor,
    this.onSelected,
    this.padding,
    this.pressElevation,
    required this.selected,
    this.selectedColor,
    this.selectedShadowColor,
    this.shadowColor,
    this.shape,
    this.showCheckmark,
    this.side,
    this.surfaceTintColor,
    this.tooltip,
    this.visualDensity,
  }) : super(
         jsonWidgetArgs: JsonChoiceChipBuilderModel.fromDynamic(
           {
             'autofocus': autofocus,
             'avatar': avatar,
             'avatarBorder': avatarBorder,
             'avatarBoxConstraints': avatarBoxConstraints,
             'backgroundColor': backgroundColor,
             'checkmarkColor': checkmarkColor,
             'chipAnimationStyle': chipAnimationStyle,
             'clipBehavior': clipBehavior,
             'color': color,
             'disabledColor': disabledColor,
             'elevation': elevation,
             'focusNode': focusNode,
             'iconTheme': iconTheme,
             'label': label,
             'labelPadding': labelPadding,
             'labelStyle': labelStyle,
             'materialTapTargetSize': materialTapTargetSize,
             'mouseCursor': mouseCursor,
             'onSelected': onSelected,
             'padding': padding,
             'pressElevation': pressElevation,
             'selected': selected,
             'selectedColor': selectedColor,
             'selectedShadowColor': selectedShadowColor,
             'shadowColor': shadowColor,
             'shape': shape,
             'showCheckmark': showCheckmark,
             'side': side,
             'surfaceTintColor': surfaceTintColor,
             'tooltip': tooltip,
             'visualDensity': visualDensity,

             ...args,
           },
           args: args,
           registry: registry,
         ),
         jsonWidgetBuilder: () => JsonChoiceChipBuilder(
           args: JsonChoiceChipBuilderModel.fromDynamic(
             {
               'autofocus': autofocus,
               'avatar': avatar,
               'avatarBorder': avatarBorder,
               'avatarBoxConstraints': avatarBoxConstraints,
               'backgroundColor': backgroundColor,
               'checkmarkColor': checkmarkColor,
               'chipAnimationStyle': chipAnimationStyle,
               'clipBehavior': clipBehavior,
               'color': color,
               'disabledColor': disabledColor,
               'elevation': elevation,
               'focusNode': focusNode,
               'iconTheme': iconTheme,
               'label': label,
               'labelPadding': labelPadding,
               'labelStyle': labelStyle,
               'materialTapTargetSize': materialTapTargetSize,
               'mouseCursor': mouseCursor,
               'onSelected': onSelected,
               'padding': padding,
               'pressElevation': pressElevation,
               'selected': selected,
               'selectedColor': selectedColor,
               'selectedShadowColor': selectedShadowColor,
               'shadowColor': shadowColor,
               'shape': shape,
               'showCheckmark': showCheckmark,
               'side': side,
               'surfaceTintColor': surfaceTintColor,
               'tooltip': tooltip,
               'visualDensity': visualDensity,

               ...args,
             },
             args: args,
             registry: registry,
           ),
         ),
         jsonWidgetType: JsonChoiceChipBuilder.kType,
       );

  final bool autofocus;

  final JsonWidgetData? avatar;

  final ShapeBorder avatarBorder;

  final BoxConstraints? avatarBoxConstraints;

  final Color? backgroundColor;

  final Color? checkmarkColor;

  final ChipAnimationStyle? chipAnimationStyle;

  final Clip clipBehavior;

  final WidgetStateProperty<Color?>? color;

  final Color? disabledColor;

  final double? elevation;

  final FocusNode? focusNode;

  final IconThemeData? iconTheme;

  final JsonWidgetData label;

  final EdgeInsetsGeometry? labelPadding;

  final TextStyle? labelStyle;

  final MaterialTapTargetSize? materialTapTargetSize;

  final MouseCursor? mouseCursor;

  final void Function(bool)? onSelected;

  final EdgeInsetsGeometry? padding;

  final double? pressElevation;

  final bool selected;

  final Color? selectedColor;

  final Color? selectedShadowColor;

  final Color? shadowColor;

  final OutlinedBorder? shape;

  final bool? showCheckmark;

  final BorderSide? side;

  final Color? surfaceTintColor;

  final String? tooltip;

  final VisualDensity? visualDensity;
}

/* AUTOGENERATED FROM [ChoiceChip]*/
/// Create a chip that acts like a radio button.
///
/// The [label], [selected], [autofocus], and [clipBehavior] arguments must
/// not be null. When [onSelected] is null, the [ChoiceChip] will be disabled.
/// The [pressElevation] and [elevation] must be null or non-negative. Typically,
/// [pressElevation] is greater than [elevation].
class JsonChoiceChipBuilderModel extends JsonWidgetBuilderModel {
  const JsonChoiceChipBuilderModel(
    super.args, {
    this.autofocus = false,
    this.avatar,
    this.avatarBorder = const CircleBorder(),
    this.avatarBoxConstraints,
    this.backgroundColor,
    this.checkmarkColor,
    this.chipAnimationStyle,
    this.clipBehavior = Clip.none,
    this.color,
    this.disabledColor,
    this.elevation,
    this.focusNode,
    this.iconTheme,
    required this.label,
    this.labelPadding,
    this.labelStyle,
    this.materialTapTargetSize,
    this.mouseCursor,
    this.onSelected,
    this.padding,
    this.pressElevation,
    required this.selected,
    this.selectedColor,
    this.selectedShadowColor,
    this.shadowColor,
    this.shape,
    this.showCheckmark,
    this.side,
    this.surfaceTintColor,
    this.tooltip,
    this.visualDensity,
  });

  final bool autofocus;

  final JsonWidgetData? avatar;

  final ShapeBorder avatarBorder;

  final BoxConstraints? avatarBoxConstraints;

  final Color? backgroundColor;

  final Color? checkmarkColor;

  final ChipAnimationStyle? chipAnimationStyle;

  final Clip clipBehavior;

  final WidgetStateProperty<Color?>? color;

  final Color? disabledColor;

  final double? elevation;

  final FocusNode? focusNode;

  final IconThemeData? iconTheme;

  final JsonWidgetData label;

  final EdgeInsetsGeometry? labelPadding;

  final TextStyle? labelStyle;

  final MaterialTapTargetSize? materialTapTargetSize;

  final MouseCursor? mouseCursor;

  final void Function(bool)? onSelected;

  final EdgeInsetsGeometry? padding;

  final double? pressElevation;

  final bool selected;

  final Color? selectedColor;

  final Color? selectedShadowColor;

  final Color? shadowColor;

  final OutlinedBorder? shape;

  final bool? showCheckmark;

  final BorderSide? side;

  final Color? surfaceTintColor;

  final String? tooltip;

  final VisualDensity? visualDensity;

  static JsonChoiceChipBuilderModel fromDynamic(
    dynamic map, {
    Map<String, dynamic> args = const {},
    JsonWidgetRegistry? registry,
  }) {
    final result = maybeFromDynamic(map, args: args, registry: registry);

    if (result == null) {
      throw Exception(
        '[JsonChoiceChipBuilder]: requested to parse from dynamic, but the input is null.',
      );
    }

    return result;
  }

  static JsonChoiceChipBuilderModel? maybeFromDynamic(
    dynamic map, {
    Map<String, dynamic> args = const {},
    JsonWidgetRegistry? registry,
  }) {
    JsonChoiceChipBuilderModel? result;

    if (map != null) {
      if (map is String) {
        map = yaon.parse(map, normalize: true);
      }

      if (map is JsonChoiceChipBuilderModel) {
        result = map;
      } else {
        registry ??= JsonWidgetRegistry.instance;
        map = registry.processArgs(map, <String>{}).value;
        result = JsonChoiceChipBuilderModel(
          args,
          autofocus: JsonClass.parseBool(map['autofocus'], whenNull: false),
          avatar: () {
            dynamic parsed = JsonWidgetData.maybeFromDynamic(
              map['avatar'],
              registry: registry,
            );

            return parsed;
          }(),
          avatarBorder: () {
            dynamic parsed = ThemeDecoder.decodeShapeBorder(
              map['avatarBorder'],
              validate: false,
            );
            parsed ??= const CircleBorder();

            return parsed;
          }(),
          avatarBoxConstraints: () {
            dynamic parsed = ThemeDecoder.decodeBoxConstraints(
              map['avatarBoxConstraints'],
              validate: false,
            );

            return parsed;
          }(),
          backgroundColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['backgroundColor'],
              validate: false,
            );

            return parsed;
          }(),
          checkmarkColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['checkmarkColor'],
              validate: false,
            );

            return parsed;
          }(),
          chipAnimationStyle: map['chipAnimationStyle'],
          clipBehavior: () {
            dynamic parsed = ThemeDecoder.decodeClip(
              map['clipBehavior'],
              validate: false,
            );
            parsed ??= Clip.none;

            return parsed;
          }(),
          color: map['color'],
          disabledColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['disabledColor'],
              validate: false,
            );

            return parsed;
          }(),
          elevation: () {
            dynamic parsed = JsonClass.maybeParseDouble(map['elevation']);

            return parsed;
          }(),
          focusNode: map['focusNode'],
          iconTheme: () {
            dynamic parsed = ThemeDecoder.decodeIconThemeData(
              map['iconTheme'],
              validate: false,
            );

            return parsed;
          }(),
          label: () {
            dynamic parsed = JsonWidgetData.fromDynamic(
              map['label'],
              registry: registry,
            );

            if (parsed == null) {
              throw Exception(
                'Null value encountered for required parameter: [label].',
              );
            }
            return parsed;
          }(),
          labelPadding: () {
            dynamic parsed = ThemeDecoder.decodeEdgeInsetsGeometry(
              map['labelPadding'],
              validate: false,
            );

            return parsed;
          }(),
          labelStyle: () {
            dynamic parsed = ThemeDecoder.decodeTextStyle(
              map['labelStyle'],
              validate: false,
            );

            return parsed;
          }(),
          materialTapTargetSize: () {
            dynamic parsed = ThemeDecoder.decodeMaterialTapTargetSize(
              map['materialTapTargetSize'],
              validate: false,
            );

            return parsed;
          }(),
          mouseCursor: () {
            dynamic parsed = ThemeDecoder.decodeMouseCursor(
              map['mouseCursor'],
              validate: false,
            );

            return parsed;
          }(),
          onSelected: map['onSelected'],
          padding: () {
            dynamic parsed = ThemeDecoder.decodeEdgeInsetsGeometry(
              map['padding'],
              validate: false,
            );

            return parsed;
          }(),
          pressElevation: () {
            dynamic parsed = JsonClass.maybeParseDouble(map['pressElevation']);

            return parsed;
          }(),
          selected: JsonClass.parseBool(map['selected'], whenNull: false),
          selectedColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['selectedColor'],
              validate: false,
            );

            return parsed;
          }(),
          selectedShadowColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['selectedShadowColor'],
              validate: false,
            );

            return parsed;
          }(),
          shadowColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['shadowColor'],
              validate: false,
            );

            return parsed;
          }(),
          shape: () {
            dynamic parsed = ThemeDecoder.decodeOutlinedBorder(
              map['shape'],
              validate: false,
            );

            return parsed;
          }(),
          showCheckmark: JsonClass.maybeParseBool(map['showCheckmark']),
          side: () {
            dynamic parsed = ThemeDecoder.decodeBorderSide(
              map['side'],
              validate: false,
            );

            return parsed;
          }(),
          surfaceTintColor: () {
            dynamic parsed = ThemeDecoder.decodeColor(
              map['surfaceTintColor'],
              validate: false,
            );

            return parsed;
          }(),
          tooltip: map['tooltip'],
          visualDensity: () {
            dynamic parsed = ThemeDecoder.decodeVisualDensity(
              map['visualDensity'],
              validate: false,
            );

            return parsed;
          }(),
        );
      }
    }

    return result;
  }

  @override
  Map<String, dynamic> toJson() {
    return JsonClass.removeNull({
      'autofocus': false == autofocus ? null : autofocus,
      'avatar': avatar?.toJson(),
      'avatarBorder': const CircleBorder() == avatarBorder
          ? null
          : ThemeEncoder.encodeShapeBorder(avatarBorder),
      'avatarBoxConstraints': ThemeEncoder.encodeBoxConstraints(
        avatarBoxConstraints,
      ),
      'backgroundColor': ThemeEncoder.encodeColor(backgroundColor),
      'checkmarkColor': ThemeEncoder.encodeColor(checkmarkColor),
      'chipAnimationStyle': chipAnimationStyle,
      'clipBehavior': Clip.none == clipBehavior
          ? null
          : ThemeEncoder.encodeClip(clipBehavior),
      'color': color,
      'disabledColor': ThemeEncoder.encodeColor(disabledColor),
      'elevation': elevation,
      'focusNode': focusNode,
      'iconTheme': ThemeEncoder.encodeIconThemeData(iconTheme),
      'label': label.toJson(),
      'labelPadding': ThemeEncoder.encodeEdgeInsetsGeometry(labelPadding),
      'labelStyle': ThemeEncoder.encodeTextStyle(labelStyle),
      'materialTapTargetSize': ThemeEncoder.encodeMaterialTapTargetSize(
        materialTapTargetSize,
      ),
      'mouseCursor': ThemeEncoder.encodeMouseCursor(mouseCursor),
      'onSelected': onSelected,
      'padding': ThemeEncoder.encodeEdgeInsetsGeometry(padding),
      'pressElevation': pressElevation,
      'selected': selected,
      'selectedColor': ThemeEncoder.encodeColor(selectedColor),
      'selectedShadowColor': ThemeEncoder.encodeColor(selectedShadowColor),
      'shadowColor': ThemeEncoder.encodeColor(shadowColor),
      'shape': ThemeEncoder.encodeOutlinedBorder(shape),
      'showCheckmark': showCheckmark,
      'side': ThemeEncoder.encodeBorderSide(side),
      'surfaceTintColor': ThemeEncoder.encodeColor(surfaceTintColor),
      'tooltip': tooltip,
      'visualDensity': ThemeEncoder.encodeVisualDensity(visualDensity),

      ...args,
    });
  }
}

class ChoiceChipSchema {
  static const id =
      'https://peiffer-innovations.github.io/flutter_json_schemas/schemas/fitd25/choice_chip.json';

  static final schema = <String, Object>{
    r'$schema': 'http://json-schema.org/draft-07/schema#',
    r'$id': id,
    'title': 'ChoiceChip',
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'autofocus': SchemaHelper.boolSchema,
      'avatar': SchemaHelper.objectSchema(JsonWidgetDataSchema.id),
      'avatarBorder': SchemaHelper.objectSchema(ShapeBorderSchema.id),
      'avatarBoxConstraints': SchemaHelper.objectSchema(
        BoxConstraintsSchema.id,
      ),
      'backgroundColor': SchemaHelper.objectSchema(ColorSchema.id),
      'checkmarkColor': SchemaHelper.objectSchema(ColorSchema.id),
      'chipAnimationStyle': SchemaHelper.anySchema,
      'clipBehavior': SchemaHelper.objectSchema(ClipSchema.id),
      'color': SchemaHelper.anySchema,
      'disabledColor': SchemaHelper.objectSchema(ColorSchema.id),
      'elevation': SchemaHelper.numberSchema,
      'focusNode': SchemaHelper.anySchema,
      'iconTheme': SchemaHelper.objectSchema(IconThemeDataSchema.id),
      'label': SchemaHelper.objectSchema(JsonWidgetDataSchema.id),
      'labelPadding': SchemaHelper.objectSchema(EdgeInsetsGeometrySchema.id),
      'labelStyle': SchemaHelper.objectSchema(TextStyleSchema.id),
      'materialTapTargetSize': SchemaHelper.objectSchema(
        MaterialTapTargetSizeSchema.id,
      ),
      'mouseCursor': SchemaHelper.objectSchema(MouseCursorSchema.id),
      'onSelected': SchemaHelper.anySchema,
      'padding': SchemaHelper.objectSchema(EdgeInsetsGeometrySchema.id),
      'pressElevation': SchemaHelper.numberSchema,
      'selected': SchemaHelper.boolSchema,
      'selectedColor': SchemaHelper.objectSchema(ColorSchema.id),
      'selectedShadowColor': SchemaHelper.objectSchema(ColorSchema.id),
      'shadowColor': SchemaHelper.objectSchema(ColorSchema.id),
      'shape': SchemaHelper.objectSchema(OutlinedBorderSchema.id),
      'showCheckmark': SchemaHelper.boolSchema,
      'side': SchemaHelper.objectSchema(BorderSideSchema.id),
      'surfaceTintColor': SchemaHelper.objectSchema(ColorSchema.id),
      'tooltip': SchemaHelper.stringSchema,
      'visualDensity': SchemaHelper.objectSchema(VisualDensitySchema.id),
    },
    'required': ['label', 'selected'],
  };
}
