import 'package:common_event/api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'theme_mode.dart';

@inject
@singleton
class AppTheme implements FiresEvents {
  AppTheme({required this.currentThemeMode, required this.eventBus});

  static Future<void> fetchAllFonts() {
    if (kReleaseMode) {
      // Disable runtime loading of fonts in release mode.
      GoogleFonts.config.allowRuntimeFetching = false;
      return GoogleFonts.pendingFonts([GoogleFonts.rajdhaniTextTheme()]);
    }
    return Future.value();
  }

  final CurrentThemeMode currentThemeMode;
  late final _materialTheme = _defaultMaterialTheme();
  @override
  final EventBus eventBus;
  late final Event eventOnUpdate = AnonymousEvent();

  @override
  EventId get eventIdOnUpdate => eventOnUpdate.eventId();

  TextStyle get metricsTextStyle => currentMaterialTheme().textTheme.headlineMedium!.copyWith(
        color: Colors.black,
      );

  ({ThemeData light, ThemeData dark}) defaultMaterialTheme() {
    return _materialTheme;
  }

  ThemeData currentMaterialTheme() {
    return currentThemeMode.themeMode == ThemeMode.dark
        ? _materialTheme.dark
        : _materialTheme.light;
  }

  Widget withSliderLargeRange(Widget child) {
    return Builder(builder: (context) {
      SliderThemeData sliderThemeData = SliderTheme.of(context).copyWith(
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
      );
      return SliderTheme(
        data: sliderThemeData,
        child: child,
      );
    });
  }

  // Returns the light mode & dark mode themeData respectively
  ({ThemeData light, ThemeData dark}) _defaultMaterialTheme() {
    final rajdhaniTextTheme = GoogleFonts.rajdhaniTextTheme();

    final ThemeData lightThemeData = ThemeData.light(useMaterial3: true);
    final ThemeData lightTheme = lightThemeData.copyWith(
        sliderTheme: lightThemeData.sliderTheme.copyWith(
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 5.0),
          inactiveTickMarkColor: Colors.greenAccent.withOpacity(1),
          activeTickMarkColor: Colors.greenAccent.withOpacity(1),
          activeTrackColor: Colors.greenAccent.withOpacity(0.5),
          inactiveTrackColor: Colors.greenAccent.withOpacity(0.15),
          thumbColor: Colors.greenAccent,
          showValueIndicator: ShowValueIndicator.always,
          valueIndicatorColor: Colors.greenAccent,
          valueIndicatorTextStyle: rajdhaniTextTheme.headlineMedium,
        ),
        textTheme: rajdhaniTextTheme,
        switchTheme: lightThemeData.switchTheme.copyWith(
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.greenAccent;
            } else {
              return Colors.redAccent;
            }
          }),
          thumbColor: const WidgetStatePropertyAll(Colors.black),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.black),
        ));

    final ThemeData darkThemeData = ThemeData.dark(useMaterial3: true);
    final ThemeData darkTheme = darkThemeData.copyWith(
        sliderTheme: darkThemeData.sliderTheme.copyWith(
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 5.0),
          inactiveTickMarkColor: Colors.greenAccent.withOpacity(1),
          activeTickMarkColor: Colors.greenAccent.withOpacity(1),
          activeTrackColor: Colors.greenAccent.withOpacity(0.5),
          inactiveTrackColor: Colors.greenAccent.withOpacity(0.15),
          thumbColor: Colors.greenAccent,
          showValueIndicator: ShowValueIndicator.always,
          valueIndicatorColor: Colors.greenAccent,
          valueIndicatorTextStyle: rajdhaniTextTheme.headlineMedium,
        ),
        textTheme: rajdhaniTextTheme,
        switchTheme: darkThemeData.switchTheme.copyWith(
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.greenAccent;
            } else {
              return Colors.redAccent;
            }
          }),
          thumbColor: const WidgetStatePropertyAll(Colors.black),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.black),
        ));
    return (light: lightTheme, dark: darkTheme);
  }

  /// UPDATE: When appTheme is updated
  TextStyle bucketCountStyle() {
    return currentMaterialTheme().textTheme.labelMedium!.copyWith(
          fontStyle: FontStyle.normal,
          fontWeight: FontWeight.normal,
        );
  }
}
