import 'package:flutter/material.dart';

import 'overlay_view.dart';

/// A input widget that follows the principle: "Big when it needs to be. Small otherwise."
///
/// This is an input taking widget that minimizes to icon or expands to an overlay when
/// receiving user input. The icon expands to overlay upon being triggered via hovering or tapping
/// in the icon.
///
/// Currently displays as icon when minimized, but we can also consider taking any widget with a
/// natural size.
///
/// Use this widget to be efficient with your UI. Use icons instead of text & size them to your
/// choice (typically very small) while also making the input as big as possible when taking input.
///
/// Any input widget is supported; for e.g. Slider, TextField etc.
class IconOrInput extends StatelessWidget {
  IconOrInput(
      {this.uniqueId,
      this.bgColor,
      required this.inputWidgetProvider,
      this.iconColor,
      required this.iconData})
      : super(key: ValueKey((uniqueId) ?? ""));

  final String? uniqueId;

  final Widget Function() inputWidgetProvider;
  final IconData iconData;
  final Color? bgColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return OverlayViewWidget(
      child: Container(
        color: bgColor,
        child: FittedBox(
            fit: BoxFit.contain,
            child: Icon(
              iconData,
              color: iconColor,
            )),
      ),
      iconExpansionBuilder: (outerContext, overlayContext, box) {
        Size size = box.size;
        return SliderTheme(
          data: SliderTheme.of(outerContext),
          child: Container(
            margin: EdgeInsetsDirectional.fromSTEB(size.width, 0, 0, 0),
            decoration: const BoxDecoration(
              color: Color.fromARGB(170, 0, 0, 0),
            ),
            child: inputWidgetProvider(),
          ),
        );
      },
    );
  }
}
