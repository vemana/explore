import 'package:checks/checks.dart';
import 'package:common_event/api.dart';
import 'package:common_testing/api.dart';
import 'package:galtonboard/src/state/simstate.dart';
import 'package:galtonboard/src/state/state.inject.module.dart';
import 'package:test/test.dart';

import 'simstate.module.dart';

SimStateTestInjectLibrary? injector;
RemoteControlledTickNotifier? tickNotifier;
EventBus? eventBus;
final TestRule injectTestRule = TestRule.from(setup: () {
  injector = SimStateTestInjectLibrary.create(stateModule: StateModule());
  tickNotifier = injector!.tickNotifier;
  eventBus = injector!.eventBus;
}, tearDown: () {
  eventBus = null;
  tickNotifier = null;
  injector = null;
});

void main() {
  _groupSimState();
}

void _groupSimState() {
  group("SimState tests", () {
    TestRuleChain(rules: [injectTestRule]).applyToEachTest();
    test("zero ticks", () {
      SimState simState =
          _freshSimState(levels: 4, slotsPerLevelBits: 3, totalPoints: 100, slotsPerFrame: 5);
      check(simState.state).identicalTo(SimControlState.running);
      check(simState.points.points).length.isCloseTo(0, 0);
    });

    test("first tick", () {
      SimState simState =
          _freshSimState(levels: 4, slotsPerLevelBits: 3, totalPoints: 100, slotsPerFrame: 5);

      tickNotifier!.tick();
      check(simState.points.points).length.isCloseTo(5, 0);
      check(simState.fps).isFinite();
    });

    test("second tick", () {
      SimState simState =
          _freshSimState(levels: 4, slotsPerLevelBits: 3, totalPoints: 100, slotsPerFrame: 5);

      // 2 ticks
      tickNotifier!.tick();
      tickNotifier!.tick();

      check(simState.points.points).length.isCloseTo(10, 0);
      // The following snippet demonstrates deep chaining
      check(simState.points.points)
        ..isNotEmpty()
        ..length.isCloseTo(10, 0)
        ..length.which((x) => x
          ..isCloseTo(10, 0)
          ..isCloseTo(10, 0))
        ..length.isCloseTo(10, 0)
        ..isNotEmpty();

      check(simState.fps).isFinite();
    });

    test("last tick", () {
      SimState simState = _freshSimState(
          levels: 4, slotsPerLevelBits: 3, totalPoints: 100, slotsPerFrame: 5, slotsIntoBucket: 1);

      for (int i = 0; i < 1000; i++) {
        tickNotifier!.tick();
      }

      check(simState.points.points).length.isCloseTo(0, 0);
      check(simState.state).identicalTo(SimControlState.completed);
      check(simState.fps).isFinite();
    });
  });
}

SimState _freshSimState(
    {int slotsPerFrame = 5,
    int levels = 4,
    int slotsPerLevelBits = 3,
    int totalPoints = 100,
    int slotsIntoBucket = 15,
    double probSuccess = 0.5}) {
  return SimState(
      levels: levels,
      slotsPerLevelBits: slotsPerLevelBits,
      slotsIntoBucket: slotsIntoBucket,
      probSuccess: probSuccess,
      totalPoints: totalPoints,
      tickNotifier: tickNotifier!,
      slotsPerFrame: slotsPerFrame,
      eventBus: eventBus);
}
