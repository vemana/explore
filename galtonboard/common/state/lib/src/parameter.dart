import 'package:built_collection/built_collection.dart';
import 'package:common_event/api.dart';

/// Reperesents a changeable parameter.
class Parameter<T> with FiresEventsMixin implements FiresEvents {
  Parameter(
      {required BuiltList<T> allowedValues,
      required int initialIndex,
      this.uniqueId,
      required eventBus}) {
    if (T == bool) {
      if (!allowedValues.contains(true) || !allowedValues.contains(false)) {
        throw ArgumentError("Specify both true and false in allowed values");
      }
      this.allowedValues = [true as T, false as T].build();
      _selectedIndex = (allowedValues[initialIndex] as bool) ? 0 : 1;
    } else {
      this.allowedValues = allowedValues;
      _selectedIndex = initialIndex;
    }
    this.eventBus = eventBus;
  }

  final String? uniqueId;
  late final BuiltList<T> allowedValues;
  late int _selectedIndex;

  T get val => allowedValues[_selectedIndex];

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int idx) {
    _selectedIndex = idx;
    fireUpdateEvent();
  }

  int numDistinctValues() {
    return allowedValues.length;
  }
}
