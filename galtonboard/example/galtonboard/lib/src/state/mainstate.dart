import 'package:inject_annotation/inject_annotation.dart';

import 'simcontrol.dart';

@singleton
@inject
class MainState {
  MainState({
    required this.simControl,
  });

  final SimStateController simControl;
}
