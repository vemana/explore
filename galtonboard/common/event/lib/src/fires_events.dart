import 'eventbus.dart';

/// An interface for classes that want to indicate that something changed (i.e. update) with them.
abstract interface class FiresEvents {
  /// The EventBus on which updates are communicated.
  EventBus get eventBus;

  /// The event id of any update events fired by this class.
  EventId get eventIdOnUpdate;
}

/// A convenience mixin to implement update notifications. Mix this into your class and invoke
/// `fireUpdateEvent` to communicate updates.
mixin class FiresEventsMixin implements FiresEvents {
  @override
  late final EventBus eventBus;
  late final Event _eventOnUpdate = AnonymousEvent();
  @override
  late final EventId eventIdOnUpdate = _eventOnUpdate.eventId();

  void fireUpdateEvent() {
    eventBus.sendEvent(_eventOnUpdate);
  }
}
