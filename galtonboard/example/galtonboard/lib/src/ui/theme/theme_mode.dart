import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

@singleton
@inject
class CurrentThemeMode {
  // The default dark mode.
  // At some point, we can change this as required
  final ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
}
