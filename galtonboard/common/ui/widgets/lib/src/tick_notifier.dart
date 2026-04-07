import 'package:flutter/scheduler.dart';

typedef ListenerFn = void Function();

abstract interface class TickNotifier {
  void addListener(ListenerFn fn);

  void removeListener(ListenerFn fn);

  void pause();

  void start();

  void dispose();
}

class ManualTickNotifier implements TickNotifier {
  ManualTickNotifier() {
    ticker = Ticker(_sendTickForDuration);
    ticker.stop();
  }

  final Set<ListenerFn> listeners = {};

  // TickNotifier? delegate;
  late final Ticker ticker;

  @override
  void addListener(ListenerFn fn) {
    // print("Adding listener to ticknotifier. current size = ${listeners.length}");
    listeners.add(fn);
  }

  @override
  void start() {
    if (!ticker.isActive) ticker.start();
  }

  @override
  void pause() {
    if (ticker.isActive) ticker.stop();
  }

  @override
  void removeListener(ListenerFn fn) {
    // print("Removing listener to ticknotifier. current size = ${listeners.length}");
    listeners.remove(fn);
  }

  @override
  void dispose() {
    pause();
    listeners.clear();
    ticker.dispose();
  }

  void _sendTickForDuration(Duration duration) {
    for (var l in listeners) {
      l();
    }
  }
}

class ManualTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    Ticker ticker = Ticker(onTick);
    ticker.stop();
    return ticker;
  }
}
