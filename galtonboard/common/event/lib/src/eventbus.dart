/// An event indicates something of interest. It can be originated by any class, communicated via
/// an event bus and listened to by any listeners interested in it.
abstract interface class Event {
  EventId eventId();
}

/// An id for the event. Allows subscribers to narrow the events they are interested in.
interface class EventId {
  /// By convention, the record should have at least one component named 'type' with a String
  /// value identifying the record.
  EventId(this.record);

  final Record record;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventId && runtimeType == other.runtimeType && record == other.record;

  @override
  int get hashCode => record.hashCode;

  @override
  String toString() {
    return 'EventId{record: $record}';
  }
}

/// Listener interface for subscribers listening to events.
typedef EventListener<T extends Event> = void Function(T);

/// An Event bus abstraction - facilitating message communication between a publisher and a
/// subscriber. The subscriber first registers with the `eventBus.subscribe` method. The active
/// subscriptions will be notified when an event is published via `eventBus.sendEvent(event)`.
///
/// Once a subscription's `cancel()` method is invoked, it becomes inactive. In particular, the
/// eventBus will no longer hold a reference to the subscriber thus making the subscriber eligible
/// for garbage collection. Ensure that you `cancel()` your subscriptions to avoid memory leaks!!
abstract interface class EventBus {
  factory EventBus.create() {
    return _EventBus();
  }

  void sendEvent(Event event);

  EventSubscription subscribe<T extends Event>(EventId eventId, EventListener<T> listener);
}

/// Represents a handle to the subscription. You can use this to cancel the subscription. Typically,
/// subscription cancellation is done as part of a dispose-like method. Ensure that you call it
/// to make the listener eligible for garbage collection.
abstract interface class EventSubscription {
  void cancel();
}

/// An anonymous event, intended to be fired only by exactly one object. Handy when the only thing
/// we are interested in is "something changed in this object X" rather than details of the change.
class AnonymousEvent implements Event {
  AnonymousEvent() {
    // int can go upto 2^53 without issues. So, just use int for counter type.
    id = _counter++;
  }

  static int _counter = 0;

  late final int id;

  @override
  EventId eventId() {
    return EventId((type: "Anonymous", counter: id));
  }
}

///////////////////////// The rest is private impl detail ///////////////////////

class _EventBus implements EventBus {
  final Map<EventId, Set<EventListener>> _typeToSubscribers = {};

  @override
  void sendEvent(Event event) {
    for (var listener in _typeToSubscribers[event.eventId()] ?? {}) {
      listener(event);
    }
  }

  @override
  EventSubscription subscribe<T extends Event>(EventId eventId, EventListener<T> listener) {
    _typeToSubscribers.putIfAbsent(eventId, () => {}).add(listener as EventListener);
    return _EventSubscription(
      listener: listener,
      eventId: eventId,
      eventBus: this,
    );
  }

  void _remove(_EventSubscription eventSubscription) {
    var eventId = eventSubscription.eventId;
    bool removed = _typeToSubscribers[eventId]?.remove(eventSubscription.listener) ?? false;
    if (!removed) {
      throw StateError("Event subscription could not be removed. EventId $eventId");
    }
    if (_typeToSubscribers[eventId]!.isEmpty) {
      _typeToSubscribers.remove(eventId);
    }
  }
}

class _EventSubscription implements EventSubscription {
  _EventSubscription({required this.listener, required this.eventId, required this.eventBus});

  final EventListener listener;
  final _EventBus eventBus;
  final EventId eventId;

  @override
  void cancel() {
    eventBus._remove(this);
  }

  @override
  String toString() {
    return '_EventSubscription{eventId: $eventId}';
  }
}
