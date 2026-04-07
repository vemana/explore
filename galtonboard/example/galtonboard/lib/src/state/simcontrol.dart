import 'dart:math';

import 'package:common_event/api.dart';
import 'package:common_state/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'simstate.dart';
import 'state.inject.names.dart' as names;

/// Maintains an active simulation depending upon supplied [Parameter]s. When a Parameter changes,
/// decides how to update the simulation; for e.g. create a new one, speed/slow it down to respect
/// a change in parameters among others.

@singleton
@inject
class SimParams {
  SimParams(
    @names.levelsParam this.levelsParam,
    @names.countParam this.countParam,
    @names.biasParam this.biasParam,
    @names.speedParam this.levelsPerSecParam,
  );

  final Parameter<int> levelsParam;
  final Parameter<int> countParam;
  final Parameter<double> biasParam;
  final Parameter<double> levelsPerSecParam;
}

@singleton
@inject
class SimStateController with FiresEventsMixin implements FiresEvents {
  SimStateController(this.simParams, this.tickNotifier, EventBus eventBus) {
    this.eventBus = eventBus;
    // When only speed changes, no need to restart
    subs.add(eventBus.subscribe(simParams.levelsPerSecParam.eventIdOnUpdate,
        (Event event) => _paramUpdated(event, createFreshSim: false)));
    subs.add(eventBus.subscribe(simParams.levelsParam.eventIdOnUpdate, _paramUpdated));
    subs.add(eventBus.subscribe(simParams.countParam.eventIdOnUpdate, _paramUpdated));
    subs.add(eventBus.subscribe(simParams.biasParam.eventIdOnUpdate, _paramUpdated));

    // Despite typing as SimState? (in order to release memory) it's never null.
    startFreshSimulation();
  }

  static const int fps = 60;
  static const int slotsPerLevelBits = 7;
  static const int slotsPerLevel = (1 << slotsPerLevelBits); // 128. Keep this near 120.
  static const int slotsIntoBucket = slotsPerLevel;
  static const double surroundWhitespace = 5;

  final SimParams simParams;
  final TickNotifier tickNotifier;
  final List<EventSubscription> subs = [];

  get _slotsPerFrame => max(1, (slotsPerLevel * simParams.levelsPerSecParam.val / fps).toInt());

  SimState? _simState;

  // API usage:
  // _startNew, (startFreshSimulation, (pause, resume)* [pause])* dispose.
  // isCompleted can be used anytime

  SimState get currentSimState => _simState!;

  void startFreshSimulation() {
    _removeCurrent();
    _startNew();
    fireUpdateEvent();
  }

  void _startNew() {
    _simState = SimState(
      probSuccess: simParams.biasParam.val,
      levels: simParams.levelsParam.val,
      slotsPerFrame: _slotsPerFrame,
      slotsPerLevelBits: slotsPerLevelBits,
      totalPoints: simParams.countParam.val,
      slotsIntoBucket: slotsIntoBucket,
      tickNotifier: tickNotifier,
      eventBus: eventBus,
    );
  }

  void _paramUpdated(Event _, {bool createFreshSim = true}) {
    if (createFreshSim) {
      startFreshSimulation();
    } else {
      if (!_simState!.isCompleted) {
        _simState?.slotsPerFrame = _slotsPerFrame;
      } else {
        startFreshSimulation();
      }
    }
  }

  void _removeCurrent() {
    _simState?.dispose();
    _simState = null;
  }

  void dispose() {
    _removeCurrent();
    for (var sub in subs) {
      sub.cancel();
    }
    subs.clear();
  }
}
