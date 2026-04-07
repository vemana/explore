import 'package:flutter/material.dart';

/// Display the given widget as a full page overlay. Dismiss the overlay when a click occurs
/// outside the child's area. This means that the specified child should
class OverlayFullpage extends StatefulWidget {
  const OverlayFullpage({super.key, required this.child});

  final Widget child;

  @override
  State<StatefulWidget> createState() {
    return _OverlayFullpageState();
  }
}

class _OverlayFullpageState extends State<OverlayFullpage> {
  OverlayEntry? _entry;
  GlobalKey iconKey = GlobalKey();

  void _dismissHelp() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _showHelp(),
        child: NotificationListener<LayoutChangedNotification>(
          onNotification: (note) {
            Future.delayed(Duration.zero, () => _entry?.markNeedsBuild());
            return true;
          },
          child: SizeChangedLayoutNotifier(
            child: FittedBox(
                key: iconKey,
                fit: BoxFit.contain,
                child: Container(
                  // decoration: BoxDecoration(
                  //   color: Colors.black,
                  //   shape: BoxShape.circle,
                  // ),
                  child: const Icon(
                    Icons.help_center_outlined,
                    color: Colors.greenAccent,
                  ),
                )),
          ),
        ),
      ),
    );
  }

  void _showHelp() {
    if (_entry != null) return;
    var overlayEntry = OverlayEntry(builder: (context) {
      RenderBox box = iconKey.currentContext!.findRenderObject() as RenderBox;
      Offset position = box.localToGlobal(Offset.zero);
      Size size = box.size;
      return GestureDetector(
        onTap: _dismissHelp,
        // With this param: we get events from clicks anywhere inside the Outer Container
        // Without, but Outer container has background color: Same as above.
        // Without, but Outer container has no bg color: only get events from Inner Container
        // In other words, whether the Container is visible or not determines
        // GestureDetector's behavior.
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: double.infinity,
          width: double.infinity,
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: 0.7,
            child: Container(
                margin: EdgeInsets.fromLTRB(position.dx + size.width, 0, 0, 0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  color: const Color.fromARGB(200, 0, 0, 0),
                ),
                padding: const EdgeInsets.all(20),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    widget.child,
                  ],
                )),
          ),
        ),
      );
    });
    _entry = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
    setState(() {});
  }
}
