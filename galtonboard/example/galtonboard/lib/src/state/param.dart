sealed class Param {}

interface class ParamError<T> {}

interface class ParamValidator<T> {}

class AllowedValues<T> {
  AllowedValues.fromList(List<T> allowedValues) : values = List.unmodifiable(allowedValues);

  final List<T> values;
}

class ObjectParam extends Param {
  // Map<String, Param> : name -> Param
}

class BoolParam extends Param {}

class StringParam extends Param {}

class IntParam extends Param {}

class DoubleParam extends Param {}

class NumValuedSlider {}
