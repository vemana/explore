import 'package:common_state/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';

@immutable
class ParameterView {
  const ParameterView(this._parameter);

  final Parameter<dynamic> _parameter;

  Widget widget() {
    if (_parameter.runtimeType == Parameter<bool>) {
      return _asToggle();
    } else {
      return _asSlider();
    }
  }

  Widget _asSlider() {
    return guard(_parameter, () {
      return Slider(
        key: _parameter.uniqueId != null ? ValueKey(_parameter.uniqueId) : null,
        value: _parameter.selectedIndex.toDouble(),
        min: 0,
        max: _parameter.numDistinctValues() - 1,
        divisions: _parameter.numDistinctValues() - 1,
        onChanged: (dbl) => _parameter.setSelectedIndex(dbl.toInt()),
        label: _render(_parameter.val),
      );
    });
  }

  Widget _asToggle() {
    if (_parameter.runtimeType != Parameter<bool>) {
      throw ArgumentError("Parameter's type is not bool for ${_parameter.runtimeType}");
    }
    return guard(_parameter, () {
      return Switch(
        value: _parameter.val as bool,
        onChanged: (val) => _parameter.setSelectedIndex(val ? 0 : 1),
      );
    });
  }
}

String _render(dynamic value) {
  if (value is int) {
    if (value < 1000) return "$value";
    if (value < 1000000) return "${(value ~/ 1000)}K";
    return "${value ~/ 1000000}M";
  }
  return value.toStringAsFixed(2);
}
