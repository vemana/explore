import 'package:common_event/api.dart';
import 'package:flutter/widgets.dart';

/// Extend your CustomPainters from this class to trigger repaints without rebuilds.
///
/// Often, CustomPainter instances don't need to be rebuilt, just repainted. In such cases,
/// instead of rebuilding on updates sent by X, repaint on updates sent by X by
/// specifying the constructor parameter [repaintOn], as `repaintOn: [X]`. If you want to update
/// on updates sent by X, Y or Z, use `repaintOn: [X,Y,Z]` and so on.
///
/// This method is particularly relevant when the CustomPainter is caching some information that
/// would get lost upon rebuilds.
///
/// See also:
///
///  * [guard] method rebuilds (not repaints) its widget upon receiving an Event update.
abstract class RepaintableCustomPainter extends CustomPainter {
  /// Triggers repaints when any of the event firers in [repaintOn] fires an event.
  RepaintableCustomPainter({List<FiresEvents>? repaintOn})
      : super(
            repaint: repaintOn != null && repaintOn.isNotEmpty ? _guardRepaints(repaintOn) : null);
}

/// Triggers a rebuild - specified by [fn] - when [toGuard] sends an update event.
/// Using methods like this you can readably/accessibly specify the State dependencies of your
/// Widget.
///
/// This snippet creates a new Container any time obj sends an update event. Usually, obj sends the
/// update event when any of its mutable properties change. A mutable property in this context is
/// a field, a getter or a non-void method whose value can change over time. Pay particular
/// attention to mutable methods when they aggregate child information. So, if you have a method
/// like `getChildName()`, it presumably is implemented like `child.getName()`. This is a
/// mutable property - even if the child reference is final, the name of the child could change
/// over time and this class should fire an update whenever the child's name changes. In effect,
/// treat `getChildName()` as a field of this class. Since we have to fire an update event whenever
/// a mutable field changes, we also have to fire one when `getChildName()`'s output changes.
///
/// ```
/// guard(obj, () {
///   return Container(color: obj.color,...);
/// });
/// ```
Widget guard(FiresEvents toGuard, Widget Function() fn) {
  return _RebuildOnEventWidget(
    eventBus: toGuard.eventBus,
    eventsToRebuildOn: [toGuard.eventIdOnUpdate],
    builder: (context) => fn(),
  );
}

Widget guardMany(List<FiresEvents> toGuard, Widget Function() fn) {
  return _RebuildOnEventWidget(
    eventBus: toGuard[0].eventBus,
    eventsToRebuildOn: toGuard.map((tg) => tg.eventIdOnUpdate).toList(growable: false),
    builder: (context) => fn(),
  );
}

/////////////////////// The rest is private impl detail /////////////////////

/// Guards repaints:
Listenable _guardRepaints(List<FiresEvents> firers) {
  return _EventRepaintable(
      eventBus: firers[0].eventBus,
      eventsToRebuildOn: firers.map((firer) => firer.eventIdOnUpdate).toList(growable: false));
}

/// A stateful widget that rebuilds on events specified by [eventsToRebuildOn].
class _RebuildOnEventWidget extends StatefulWidget {
  const _RebuildOnEventWidget({
    required this.eventBus,
    required this.eventsToRebuildOn,
    required this.builder,
  });

  final List<EventId> eventsToRebuildOn;
  final EventBus eventBus;
  final Widget Function(BuildContext context) builder;

  @override
  State createState() {
    return _RebuildOnEventWidgetState();
  }
}

class _RebuildOnEventWidgetState extends State<_RebuildOnEventWidget> {
  List<EventSubscription> subs = [];

  @override
  void didUpdateWidget(_RebuildOnEventWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cancelEventSubs();
    _registerEventSubs();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }

  @override
  void initState() {
    super.initState();
    _registerEventSubs();
  }

  @override
  void dispose() {
    _cancelEventSubs();
    super.dispose();
  }

  void _registerEventSubs() {
    for (EventId eventId in widget.eventsToRebuildOn) {
      subs.add(widget.eventBus.subscribe(eventId, (event) {
        setState(() {});
      }));
    }
  }

  void _cancelEventSubs() {
    for (var sub in subs) {
      sub.cancel();
    }
    subs = [];
  }
}

class _EventRepaintable implements Listenable {
  _EventRepaintable({required this.eventBus, required this.eventsToRebuildOn});

  final EventBus eventBus;
  final List<EventId> eventsToRebuildOn;
  final Map<VoidCallback, List<EventSubscription>> eventSubs = {};

  @override
  void addListener(VoidCallback listener) {
    if (eventSubs[listener] == null) {
      eventSubs[listener] =
          eventsToRebuildOn.map((id) => eventBus.subscribe(id, (_) => listener())).toList();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (eventSubs[listener] != null) {
      for (var sub in eventSubs[listener]!) {
        sub.cancel();
      }
      eventSubs.remove(listener);
    }
  }
}
