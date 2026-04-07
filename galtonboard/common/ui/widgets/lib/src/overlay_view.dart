import 'package:flutter/material.dart';

/// Supports an additional overlay view for the given child. The overlay view is provided via
/// the [iconExpansionBuilder] argument.
///
/// This widget is useful when you have both a compact representation ('child' here) and an overlay
/// representation of the same. The overlay can span the entire screen and provide more readily
/// accessible display/input capability.
class OverlayViewWidget extends StatefulWidget {
  const OverlayViewWidget({super.key, required this.child, required this.iconExpansionBuilder});

  final Widget child;

  // Return the widget. It will be placed so that its top-left matches the iconBox's topLeft.
  final Widget Function(BuildContext outerContext, BuildContext overlayContext, RenderBox iconBox)
      iconExpansionBuilder;

  @override
  State<OverlayViewWidget> createState() {
    return OverlayHelperState();
  }
}

class OverlayHelperState extends State<OverlayViewWidget> {
  // State
  OverlayEntry? _entry;
  late GlobalKey iconKey;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  void didUpdateWidget(OverlayViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (oldWidget.icon != widget.icon) {
    //   throw StateError("We don't handle config updates for OverlayHelperWidget.");
    // }
    // technically we can handle it as follows, but we are lazy.
    // When this happens, we can be in one of 2 states;
    // 1. not showing the overlay --> We can update config fairly easily
    // 2. showing an overlay --> we can remove the overlay, update config & retrigger the overlay
  }

  void _dismiss() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _showOverlay(BuildContext outerContext) {
    if (_entry != null) return;
    var overlayEntry = OverlayEntry(builder: (overlayContext) {
      RenderBox iconBox = iconKey.currentContext!.findRenderObject() as RenderBox;
      Offset position = iconBox.localToGlobal(Offset.zero);
      return Material(
          type: MaterialType.transparency,
          child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                  height: iconBox.size.height,
                  width: double.infinity,
                  transform: Transform.translate(offset: position).transform,
                  // color: Colors.blue,
                  child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                          // hoverColor: Colors.teal,
                          onTap: () {
                            _dismiss();
                          },
                          onHover: (inside) {
                            if (!inside) _dismiss();
                          },
                          child: widget.iconExpansionBuilder(
                              outerContext, overlayContext, iconBox))))));
    });
    _entry = overlayEntry;
    Overlay.of(outerContext).insert(overlayEntry);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    iconKey = GlobalKey();
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _showOverlay(context),
        onHover: (x) {
          if (x) _showOverlay(context);
        },
        child: NotificationListener<LayoutChangedNotification>(
            onNotification: (note) {
              if (_entry != null) Future.delayed(Duration.zero, () => _entry?.markNeedsBuild());
              return true;
            },
            child: SizeChangedLayoutNotifier(key: iconKey, child: widget.child)),
      ),
    );
  }
}
