import 'package:flutter/widgets.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'mainapp.inject.dart';
import 'state/mainstate.dart';
import 'state/state.inject.module.dart';
import 'ui/main.ui.dart';
import 'ui/theme/app_theme.dart';
import 'ui/ui.inject.module.dart';

void runMainApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.fetchAllFonts();

  final injector = RootInjectLibrary.create(stateModule: StateModule(), uiModule: UiModule());
  runApp(injector.mainViewFactory.create(injector.mainState).widget());
}

@Component([StateModule, UiModule])
abstract class RootInjectLibrary {
  static const create = RootInjectLibrary$Component.create;

  @inject
  MainState get mainState;

  @inject
  MainViewFactory get mainViewFactory;
}
