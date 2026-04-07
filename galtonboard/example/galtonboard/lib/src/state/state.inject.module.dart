import 'package:built_collection/built_collection.dart';
import 'package:common_event/api.dart';
import 'package:common_state/api.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'state.inject.names.dart';

@module
class StateModule {
  @provides
  @singleton
  EventBus eventBus() {
    return EventBus.create();
  }

  @provides
  @singleton
  @countParam
  Parameter<int> provideCountParam(EventBus eventBus) {
    return Parameter(
      initialIndex: 10,
      uniqueId: 'PointCount',
      eventBus: eventBus,
      allowedValues: [
        1,
        2,
        5,
        10,
        20,
        50,
        100,
        200,
        500,
        1000,
        2000,
        5000,
        10000,
        20000,
        50000,
        100000,
        200000,
        500000,
        1000000
      ].toBuiltList(),
    );
  }

  @provides
  @singleton
  @speedParam
  Parameter<double> provideLevelsPerSecParam(EventBus eventBus) {
    return Parameter(
        eventBus: eventBus,
        allowedValues: List.generate(40, (i) => (i + 1) * 0.5).toBuiltList(),
        initialIndex: 10,
        uniqueId: 'Speed');
  }

  @provides
  @singleton
  @levelsParam
  Parameter<int> provideLevelsParam(EventBus eventBus) {
    return Parameter(
        allowedValues: List.generate(99, (i) => i + 2).toBuiltList(),
        initialIndex: 10,
        uniqueId: 'Levels',
        eventBus: eventBus);
  }

  @provides
  @singleton
  @biasParam
  Parameter<double> provideBiasParam(EventBus eventBus) {
    return Parameter(
      allowedValues: List.generate(101, (i) => i / 100.0).toBuiltList(),
      eventBus: eventBus,
      initialIndex: 50,
      uniqueId: 'bias',
    );
  }
}
