import 'package:common_state/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../state/help.dart';
import '../state/mainstate.dart';
import '../state/simstate.dart';
import '../state/state.inject.names.dart' as names;
import '../ustate/debug_panel.dart';
import 'help.ui.dart';
import 'simcontrol.ui.dart';
import 'theme/app_theme.dart';

@assistedFactory
abstract class MainViewFactory {
  MainView create(MainState mainState);
}

@assistedInject
@immutable
class MainView implements HasWidget {
  const MainView(
    @assisted this.mainState,
    @names.levelsParam this.levelsParam,
    @names.countParam this.countParam,
    @names.biasParam this.biasParam,
    @names.speedParam this.levelsPerSecParam,
    @names.showStatsParam this.showStatsParam,
    @names.drawAtlasBatchSizeParam this.drawAtlasBatchSizeParam,
    this.simControlViewFactory,
    this.helpViewFactory,
    this.appTheme,
    this.help,
    this.tickerProvider,
    this.debugPanel,
  );

  // State
  final MainState mainState;

  // UState
  final SimControlViewFactory simControlViewFactory;
  final HelpViewFactory helpViewFactory;
  final Parameter<int> levelsParam;
  final Parameter<int> countParam;
  final Parameter<double> biasParam;
  final Parameter<double> levelsPerSecParam;
  final Parameter<bool> showStatsParam;
  final Parameter<int> drawAtlasBatchSizeParam;
  final AppTheme appTheme;
  final HelpState help;
  final TickerProvider tickerProvider;
  final DebugPanel debugPanel;

  @override
  Widget widget() {
    return guard(appTheme, () {
      final (light: lightTheme, dark: darkTheme) =
          appTheme.defaultMaterialTheme();
      return MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: appTheme.currentThemeMode.themeMode,
        home: Scaffold(body: _mainView()),
      );
    });
  }

  Widget _mainView() {
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OverlayFullpage(
                          child:
                              helpViewFactory.create(helpState: help).widget()),
                      _statsToggler(),
                      _iconOverlay(levelsParam, Icons.stairs_outlined,
                          useLargeSlider: true),
                      _iconOverlay(levelsPerSecParam, Icons.speed_sharp),
                      _iconOverlay(biasParam, Icons.balance_rounded,
                          useLargeSlider: true),
                      _iconOverlay(countParam, Icons.grain),
                      _pauseResumer(),
                      _replayer(),
                      _debugPanelButton(true),
                    ].map((child) => Expanded(flex: 1, child: child)).toList(),
                  ),
                ),
                guard(debugPanel, () {
                  return AnimatedFractionallySizedBox(
                    curve: Curves.elasticInOut,
                    duration: const Duration(milliseconds: 1000),
                    heightFactor: 1,
                    widthFactor: debugPanel.isVisible() ? 1 : 0,
                    alignment: Alignment.center,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.black),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 1, child: _debugPanel()),
                          Expanded(flex: 1, child: _debugPanelButton(false)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            )),
        Expanded(
          flex: 97,
          child: SizedBox.expand(
            child: simControlViewFactory
                .create(simControl: mainState.simControl)
                .widget(),
          ),
        ),
      ],
    );
    // });
  }

  Widget _debugPanelButton(bool setTrue) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          debugPanel.setVisible(setTrue);
        },
        child: FittedBox(
          fit: BoxFit.contain,
          child: Icon(
            setTrue ? Icons.bug_report : Icons.arrow_back_sharp,
            color: setTrue ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
      ),
    );
  }

  Widget _debugPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _iconOverlay(drawAtlasBatchSizeParam, Icons.batch_prediction),
      ].map((child) => Expanded(flex: 1, child: child)).toList(),
    );
  }

  Widget _iconOverlay<T>(Parameter<T> param, IconData icondata,
      {bool useLargeSlider = false}) {
    Widget iconOrInput = IconOrInput(
      inputWidgetProvider: ParameterView(param).widget,
      uniqueId: param.uniqueId,
      iconData: icondata,
      iconColor: Colors.greenAccent,
      bgColor: Colors.black,
    );
    if (!useLargeSlider) return iconOrInput;
    return appTheme.withSliderLargeRange(iconOrInput);
  }

  /// NOTE THE PATTERN. Whenever you access X.f, use a
  /// `guard(X, (){...})`
  ///
  /// Because we are going to access mutable properties of simControl like `current`, we need to
  /// guard access again with a guard(simControl, () {...}) and access the
  /// `simControl.current` inside the widget builder. We then pass this `currentSim` to another
  /// method which once again guards with guard(currentSim) before
  /// accessing mutable properties.
  ///
  /// Also, we have a refence to `mainState.simControl` argument which is either protected by an
  /// upper level `guard(mainState)` or mainState is just immutable (so no need for guard).
  Widget _pauseResumer() {
    final simControl = mainState.simControl;
    return guard(simControl, () {
      final currentSim = simControl.currentSimState;
      return guard(currentSim, () {
        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: switch (currentSim.state) {
              SimControlState.running => currentSim.pause,
              SimControlState.completed => simControl.startFreshSimulation,
              SimControlState.paused => currentSim.resume,
            },
            child: FittedBox(
              fit: BoxFit.contain,
              child: Icon(
                switch (currentSim.state) {
                  SimControlState.running => Icons.pause,
                  SimControlState.completed => Icons.start,
                  SimControlState.paused => Icons.play_circle,
                },
                color: Colors.greenAccent,
              ),
            ),
          ),
        );
      });
    });
  }

  Widget _replayer() {
    final simControl = mainState.simControl;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: simControl.startFreshSimulation,
        child: const FittedBox(
          fit: BoxFit.contain,
          child: Icon(
            Icons.replay,
            color: Colors.greenAccent,
          ),
        ),
      ),
    );
  }

  Material _statsToggler() {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onHover: (i) {},
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            const Expanded(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Icon(
                  Icons.analytics_outlined,
                  color: Colors.greenAccent,
                ),
              ),
            ),
            Expanded(
                flex: 1,
                child: FittedBox(
                    fit: BoxFit.contain,
                    child: ParameterView(showStatsParam).widget())),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
