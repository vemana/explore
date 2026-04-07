import 'package:common_event/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../state/simcontrol.dart';
import 'simstate.ui.dart';
import 'theme/app_theme.dart';

@assistedFactory
abstract class SimControlViewFactory {
  SimControlView create({required SimStateController simControl});
}

@assistedInject
class SimControlView implements HasWidget {
  SimControlView(
      {@assisted required this.simControl,
      required this.eventBus,
      required this.appTheme,
      required this.simStateViewFactory});

  final SimStateController simControl;
  final SimStateViewFactory simStateViewFactory;
  final EventBus eventBus;
  final AppTheme appTheme;

  @override
  Widget widget() {
    return guard(simControl, () {
      // Since simState rebuilds a lot, pass this as a parameter instead.
      // Looking up theme seems to have significant time variance due to a hashmap inside.
      return simStateViewFactory.create(simState: simControl.currentSimState).widget();
    });
  }
}
