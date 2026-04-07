import 'package:built_collection/built_collection.dart';
import 'package:common_event/api.dart';
import 'package:common_state/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/animation.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../state/state.inject.names.dart';

@module
class UiModule {
  @provides
  @singleton
  @drawAtlasBatchSizeParam
  Parameter<int> provideDrawAtlasBatchSizeParam(EventBus eventBus) {
    return Parameter<int>(
      eventBus: eventBus,
      allowedValues: [for (int i = 10; i <= 16; i++) (1 << i)].toBuiltList(),
      initialIndex: 1, // 1<<11 = 2048
      uniqueId: 'DrawAtlasBatchSize',
    );
  }

  @provides
  @singleton
  @showStatsParam
  Parameter<bool> provideShowStatsParam(EventBus eventBus) {
    return Parameter(
      eventBus: eventBus,
      allowedValues: [true, false].toBuiltList(),
      initialIndex: 0,
      uniqueId: 'ShowStats',
    );
  }

  @provides
  @singleton
  TickerProvider tickerProvider() {
    return ManualTickerProvider();
  }

  @provides
  @singleton
  TickNotifier tickNotifier() {
    return ManualTickNotifier();
  }
}
