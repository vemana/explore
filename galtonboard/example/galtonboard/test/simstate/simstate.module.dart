import 'package:common_base/api.dart';
import 'package:common_event/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:galtonboard/src/state/state.inject.module.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'simstate.module.inject.dart';

@Component([StateModule, SimStateTestOverrideModule])
abstract class SimStateTestInjectLibrary {
  static const create = SimStateTestInjectLibrary$Component.create;

  @inject
  RemoteControlledTickNotifier get tickNotifier;

  @inject
  EventBus get eventBus;
}

@module
class SimStateTestOverrideModule {
  @provides
  @singleton
  TickNotifier getTickNotifer(RemoteControlledTickNotifier tickNotifier) {
    return tickNotifier;
  }

  @provides
  @singleton
  RemoteControlledTickNotifier getRemoteControlledTickNotifier() {
    return RemoteControlledTickNotifier();
  }
}

class RemoteControlledTickNotifier implements TickNotifier {
  bool active = false;
  final Set<void Function()> listeners = {};

  void tick() {
    // Don't tick if the consumer has signalled us to stop() already. The test code which is
    // driving this tick manually is not respecting the invariants of the tick consumer. But,
    // often the test code just wants to drive as many ticks as possible. So, instead of throwing,
    // we'll accommodate it by ignoring these extra ticks.
    if (!active) return;
    for (var l in listeners) {
      l();
    }
  }

  @override
  void addListener(ListenerFn fn) {
    listeners.add(fn);
  }

  @override
  void dispose() {
    listeners.clear();
  }

  @override
  void pause() {
    assertState(active == true, "Expected state to be active");
    active = false;
  }

  @override
  void removeListener(ListenerFn fn) {
    listeners.remove(fn);
  }

  @override
  void start() {
    assertState(active == false, "Expected state to be inactive");
    active = true;
  }
}
