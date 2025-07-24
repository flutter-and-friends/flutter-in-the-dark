import 'package:confetti/confetti.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:fitd25/dart_pad/dart_pad_widget.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.challenge,
    required this.confettiController,
  });

  final Challenge challenge;
  final ConfettiController confettiController;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final JsonWidgetData jsonWidgetData;

  @override
  void initState() {
    jsonWidgetData = JsonWidgetData.fromDynamic(jsonWidget);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(
            title: switch (widget.challenge.endTime) {
              final endTime when DateTime.now().isAfter(endTime) => const Text(
                'Time over!',
              ),
              final endTime => Timeago(
                refreshRate: const Duration(seconds: 1),
                date: endTime,
                allowFromNow: true,
                builder: (context, time) {
                  // TODO: Figure out a nice way to shake screen and throw confetti
                  if (DateTime.now().isAfter(endTime)) {
                    return const Text('Time over!');
                  }
                  return Text('${widget.challenge.name} ends in $time');
                },
              ),
            },
          ),
          body: SplitPane(
            axis: Axis.horizontal,
            initialFractions: [0.5, 0.5],
            children: [
              jsonWidgetData.build(context: context),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DartPad(
                    key: Key(widget.challenge.dartPadId),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    split: 100,
                    gistId: widget.challenge.dartPadId,
                  );
                },
              ),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: widget.confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          strokeWidth: 2,
        ),
      ],
    );
  }
}

final jsonWidget = {
  "type": "scaffold",
  "args": {
    "appBar": {
      "type": "app_bar",
      "args": {
        "title": {
          "type": "text",
          "args": {"text": "Form"},
        },
      },
    },
    "backgroundColor": "#e0e0e0",
    "body": {
      "type": "safe_area",
      "args": {
        "bottom": true,
        "child": {
          "type": "form",
          "args": {
            "child": {
              "type": "single_child_scroll_view",
              "args": {
                "padding": [16, 0],
                "child": {
                  "type": "container",
                  "args": {
                    "alignment": "topCenter",
                    "width": "infinity",
                    "child": {
                      "type": "container",
                      "args": {
                        "constraints": {"maxWidth": 450},
                        "child": {
                          "type": "column",
                          "args": {
                            "mainAxisSize": "min",
                            "children": [
                              {
                                "type": "sized_box",
                                "args": {"height": 16},
                              },
                              {
                                "type": "sized_box",
                                "args": {"height": 8},
                              },
                              {
                                "type": "material",
                                "args": {
                                  "borderRadius": 16,
                                  "color": "#fff",
                                  "elevation": 4,
                                  "margin": [0, 8],
                                  "padding": 16,
                                  "child": {
                                    "type": "column",
                                    "args": {
                                      "mainAxisSize": "min",
                                      "children": [
                                        {
                                          "type": "row",
                                          "args": {
                                            "children": [
                                              {
                                                "type": "flexible",
                                                "args": {
                                                  "child": {
                                                    "type": "semantics",
                                                    "args": {
                                                      "sortKey": {
                                                        "order": 0,
                                                        "textField": true,
                                                      },
                                                      "child": {
                                                        "type":
                                                            "exclude_semantics",
                                                        "args": {
                                                          "child": {
                                                            "type":
                                                                "text_form_field",
                                                            "id": "first_name",
                                                            "args": {
                                                              "decoration": {
                                                                "hintText":
                                                                    "John",
                                                                "labelText":
                                                                    "First Name",
                                                                "suffixIcon": {
                                                                  "type":
                                                                      "icon_button",
                                                                  "args": {
                                                                    "icon": {
                                                                      "type":
                                                                          "icon",
                                                                      "args": {
                                                                        "icon": {
                                                                          "codePoint":
                                                                              57704,
                                                                          "fontFamily":
                                                                              "MaterialIcons",
                                                                          "size":
                                                                              50,
                                                                        },
                                                                      },
                                                                    },
                                                                    // "onPressed": "${set_value('first_name','')}"
                                                                  },
                                                                },
                                                              },
                                                              "validators": [
                                                                {
                                                                  "type":
                                                                      "required",
                                                                },
                                                              ],
                                                            },
                                                          },
                                                        },
                                                      },
                                                    },
                                                  },
                                                },
                                              },
                                              {
                                                "type": "sized_box",
                                                "args": {"width": 16},
                                              },
                                              {
                                                "type": "flexible",
                                                "args": {
                                                  "child": {
                                                    "type": "merge_semantics",
                                                    "args": {
                                                      "child": {
                                                        "type":
                                                            "text_form_field",
                                                        "id": "last_name",
                                                        "args": {
                                                          "decoration": {
                                                            "hintText": "Doe",
                                                            "labelText":
                                                                "Last Name",
                                                            "suffixIcon": {
                                                              "type":
                                                                  "icon_button",
                                                              "args": {
                                                                "icon": {
                                                                  "type":
                                                                      "icon",
                                                                  "args": {
                                                                    "icon": {
                                                                      "codePoint":
                                                                          57704,
                                                                      "fontFamily":
                                                                          "MaterialIcons",
                                                                      "size":
                                                                          50,
                                                                    },
                                                                  },
                                                                },
                                                                // "onPressed": "${set_value('last_name','')}"
                                                              },
                                                            },
                                                          },
                                                          "validators": [
                                                            {
                                                              "type":
                                                                  "required",
                                                            },
                                                          ],
                                                        },
                                                      },
                                                    },
                                                  },
                                                },
                                              },
                                            ],
                                          },
                                        },
                                        {
                                          "type": "sized_box",
                                          "args": {"height": 16},
                                        },
                                        {
                                          "type": "text_form_field",
                                          "id": "email_address",
                                          "args": {
                                            "decoration": {
                                              "hintText": "name@example.com",
                                              "labelText": "Email Address",
                                              "suffixIcon": {
                                                "type": "icon_button",
                                                "args": {
                                                  "icon": {
                                                    "type": "icon",
                                                    "args": {
                                                      "icon": {
                                                        "codePoint": 57704,
                                                        "fontFamily":
                                                            "MaterialIcons",
                                                        "size": 50,
                                                      },
                                                    },
                                                  },
                                                  // "onPressed": "${set_value('email_address','')}"
                                                },
                                              },
                                            },
                                            "validators": [
                                              {"type": "required"},
                                              {"type": "email"},
                                            ],
                                          },
                                        },
                                        {
                                          "type": "sized_box",
                                          "args": {"height": 16},
                                        },
                                        {
                                          "type": "dropdown_button_form_field",
                                          "id": "email_type",
                                          "args": {
                                            "decoration": {
                                              "labelText": "Email Type",
                                            },
                                            "items": ["Home", "Other", "Work"],
                                            "validators": [
                                              {"type": "required"},
                                            ],
                                          },
                                        },
                                      ],
                                    },
                                  },
                                },
                              },
                              {
                                "type": "elevated_button",
                                "id": "submit_button",
                                "args": {
                                  // "onPressed": "${validateForm('form_context')}",
                                  "child": {
                                    "type": "container",
                                    "args": {
                                      "alignment": "center",
                                      "width": "infinity",
                                      "child": {
                                        "type": "save_context",
                                        "args": {
                                          "key": "form_context",
                                          "child": {
                                            "type": "text",
                                            "args": {"text": "Submit"},
                                          },
                                        },
                                      },
                                    },
                                  },
                                },
                              },
                            ],
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
};
