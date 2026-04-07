import "dart:math" as math;

import "vec2.dart";

/// Linearly interpolate between two numbers, `a` and `b`, by an extrapolation
/// factor `t`.
///
/// When `a` and `b` are equal or both NaN, `a` is returned.  Otherwise,
/// `a`, `b`, and `t` are required to be finite or null, and the result of `a +
/// (b - a) * t` is returned, where nulls are defaulted to 0.0.
double? lerpDouble(num? a, num? b, double t) {
  if (a == b || (a?.isNaN ?? false) && (b?.isNaN ?? false)) {
    return a?.toDouble();
  }
  a ??= 0.0;
  b ??= 0.0;
  assert(a.isFinite, 'Cannot interpolate between finite and non-finite values');
  assert(b.isFinite, 'Cannot interpolate between finite and non-finite values');
  assert(t.isFinite, 't must be finite when interpolating between values');
  return a * (1.0 - t) + b * t;
}

/// Linearly interpolate between two doubles.
///
/// Same as [lerpDouble] but specialized for non-null `double` type.
double _lerpDouble(double a, double b, double t) {
  return a * (1.0 - t) + b * t;
}

/// Linearly interpolate between two integers.
///
/// Same as [lerpDouble] but specialized for non-null `int` type.
double _lerpInt(int a, int b, double t) {
  return a + (b - a) * t;
}

/// Same as [num.clamp] but specialized for non-null [int].
int _clampInt(int value, int min, int max) {
  assert(min <= max);
  if (value < min) {
    return min;
  } else if (value > max) {
    return max;
  } else {
    return value;
  }
}

/// Base class for [Dimensions] and [Position], which are both ways to describe
/// a distance as a two-dimensional axis-aligned vector.
abstract class OffsetBase {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  ///
  /// The first argument sets the horizontal component, and the second the
  /// vertical component.
  const OffsetBase(this._dx, this._dy);

  final double _dx;
  final double _dy;

  @override
  bool operator ==(Object other) {
    return other is OffsetBase &&
        runtimeType == other.runtimeType &&
        other._dx == _dx &&
        other._dy == _dy;
  }

  @override
  int get hashCode => Object.hash(_dx, _dy);

  @override
  String toString() => 'OffsetBase(${_dx.toStringAsFixed(1)}, ${_dy.toStringAsFixed(1)})';
}

class Position extends OffsetBase {
  /// Creates an position. The first argument sets [dx], the horizontal component,
  /// and the second sets [dy], the vertical component.
  const Position(super.dx, super.dy);

  /// Creates an position from its [direction] and [distance].
  ///
  /// The direction is in radians clockwise from the positive x-axis, where the y-axis increases
  /// downwards like in a computer screen. Conventionally, direction would be anti-clockwise but
  /// then y axis points upwards.
  ///
  /// The distance can be omitted, to create a unit vector (distance = 1.0).
  factory Position.fromDirection(double direction, [double distance = 1.0]) {
    return Position(distance * math.cos(direction), distance * math.sin(direction));
  }

  /// Returns the corresponding position vector. Vectors have well defined binary operations unlike
  /// Positions. So, often you want to use this method in order to transform Positions by applying
  /// translations etc.
  Vec2 toVec2() {
    return Vec2(dx, dy);
  }

  /// The x component of the position.
  double get dx => _dx;

  /// The y component of the position.
  double get dy => _dy;

  /// The magnitude of the corresponding position vector.
  double get distance => math.sqrt(dx * dx + dy * dy);

  /// The square of the magnitude of the corresponding position vector.
  double get distanceSquared => dx * dx + dy * dy;

  /// The origin
  static const Position zero = Position(0.0, 0.0);

  /// An position with infinite x and y components.
  static const Position infinite = Position(double.infinity, double.infinity);

  /// Returns the corresponding negative position; i.e. same magnitude, opposite direction.
  Position operator -() => Position(-dx, -dy);

  /// Returns the vector that when applied to [other], takes it to `this`.
  Vec2 operator -(Position other) => Vec2(dx - other.dx, dy - other.dy);

  /// Adds the given vector [other] to this Position vector.
  Position operator +(Vec2 other) => Position(dx + other.dx, dy + other.dy);

  /// Multiplication operator.
  ///
  /// See also [scale].
  Position operator *(double operand) => Position(dx * operand, dy * operand);

  /// Division operator.
  ///
  /// See also [scale].
  Position operator /(double operand) => Position(dx / operand, dy / operand);

  /// Integer (truncating) division operator.
  Position operator ~/(double operand) =>
      Position((dx ~/ operand).toDouble(), (dy ~/ operand).toDouble());

  /// Linearly interpolate between two positions.
  ///
  /// If either position is null, this function interpolates from [Position.zero].
  ///
  /// The `t` argument represents position on the timeline, with 0.0 meaning
  /// that the interpolation has not started, returning `a` (or something
  /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
  /// returning `b` (or something equivalent to `b`), and values in between
  /// meaning that the interpolation is at the relevant point on the timeline
  /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
  /// 1.0, so negative values and values greater than 1.0 are valid (and can
  /// easily be generated by curves such as [Curves.elasticInOut]).
  ///
  /// Values for `t` are usually obtained from an [Animation<double>], such as
  /// an [AnimationController].
  static Position? lerp(Position? a, Position? b, double t) {
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return a * (1.0 - t);
      }
    } else {
      if (a == null) {
        return b * t;
      } else {
        return Position(_lerpDouble(a.dx, b.dx, t), _lerpDouble(a.dy, b.dy, t));
      }
    }
  }

  /// Compares two Offsets for equality.
  @override
  bool operator ==(Object other) {
    return other is Position && other.dx == dx && other.dy == dy;
  }

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset(${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)})';
}

/// Represents a Size-like 2-d dimensions.
class Dimensions extends OffsetBase {
  /// Creates a [Dimensions] with the given [width] and [height].
  const Dimensions(super.width, super.height);

  /// Creates an instance of [Dimensions] that has the same values as another.
  // Used by the rendering library's _DebugSize hack.
  Dimensions.copy(Dimensions source) : super(source.width, source.height);

  /// Creates a square [Dimensions] whose [width] and [height] are the given dimension.
  ///
  /// See also:
  ///
  ///  * [Size.fromRadius], which is more convenient when the available size
  ///    is the radius of a circle.
  const Dimensions.square(double dimension)
      : super(dimension, dimension); // ignore: use_super_parameters

  /// Creates a [Dimensions] with the given [width] and an infinite [height].
  const Dimensions.fromWidth(double width) : super(width, double.infinity);

  /// Creates a [Dimensions] with the given [height] and an infinite [width].
  const Dimensions.fromHeight(double height) : super(double.infinity, height);

  /// Creates a square [Dimensions] whose [width] and [height] are twice the given
  /// dimension.
  ///
  /// This is a square that contains a circle with the given radius.
  ///
  /// See also:
  ///
  ///  * [Size.square], which creates a square with the given dimension.
  const Dimensions.fromRadius(double radius) : super(radius * 2.0, radius * 2.0);

  /// The horizontal extent of this size.
  double get width => _dx;

  /// The vertical extent of this size.
  double get height => _dy;

  /// The aspect ratio of this size.
  ///
  /// This returns the [width] divided by the [height].
  ///
  /// If the [width] is zero, the result will be zero. If the [height] is zero
  /// (and the [width] is not), the result will be [double.infinity] or
  /// [double.negativeInfinity] as determined by the sign of [width].
  ///
  /// See also:
  ///
  ///  * [AspectRatio], a widget for giving a child widget a specific aspect
  ///    ratio.
  ///  * [FittedBox], a widget that (in most modes) attempts to maintain a
  ///    child widget's aspect ratio while changing its size.
  double get aspectRatio {
    if (height != 0.0) {
      return width / height;
    }
    if (width > 0.0) {
      return double.infinity;
    }
    if (width < 0.0) {
      return double.negativeInfinity;
    }
    return 0.0;
  }

  /// An empty size, one with a zero width and a zero height.
  static const Dimensions zero = Dimensions(0.0, 0.0);

  /// A size whose [width] and [height] are infinite.
  ///
  /// See also:
  ///
  ///  * [isInfinite], which checks whether either dimension is infinite.
  ///  * [isFinite], which checks whether both dimensions are finite.
  static const Dimensions infinite = Dimensions(double.infinity, double.infinity);

  /// Whether this size encloses a non-zero area.
  ///
  /// Negative areas are considered empty.
  bool get isEmpty => width <= 0.0 || height <= 0.0;

  /// Pointwise Multiplication operator.
  Dimensions operator *(double operand) => Dimensions(width * operand, height * operand);

  /// Pointwise Division operator.
  Dimensions operator /(double operand) => Dimensions(width / operand, height / operand);

  /// Pointwise Integer (truncating) division operator.
  Dimensions operator ~/(double operand) =>
      Dimensions((width ~/ operand).toDouble(), (height ~/ operand).toDouble());

  /// The lesser of the magnitudes of the [width] and the [height].
  double get shortestSide => math.min(width.abs(), height.abs());

  /// The greater of the magnitudes of the [width] and the [height].
  double get longestSide => math.max(width.abs(), height.abs());

  // Convenience methods that do the equivalent of calling the similarly named
  // methods on a Rect constructed from the given origin and this size.

  /// The position to the intersection of the top and left edges of the rectangle
  /// described by the given [Position] (which is interpreted as the top-left corner)
  /// and this [Dimensions].
  ///
  /// See also [Rect.topLeft].
  Position topLeft(Position origin) => origin;

  /// The position to the center of the top edge of the rectangle described by the
  /// given position (which is interpreted as the top-left corner) and this size.
  ///
  /// See also [Rect.topCenter].
  Position topCenter(Position origin) => Position(origin.dx + width / 2.0, origin.dy);

  /// The position to the intersection of the top and right edges of the rectangle
  /// described by the given position (which is interpreted as the top-left corner)
  /// and this size.
  ///
  /// See also [Rect.topRight].
  Position topRight(Position origin) => Position(origin.dx + width, origin.dy);

  /// The position to the center of the left edge of the rectangle described by the
  /// given position (which is interpreted as the top-left corner) and this size.
  ///
  /// See also [Rect.centerLeft].
  Position centerLeft(Position origin) => Position(origin.dx, origin.dy + height / 2.0);

  /// The position to the point halfway between the left and right and the top and
  /// bottom edges of the rectangle described by the given position (which is
  /// interpreted as the top-left corner) and this size.
  ///
  /// See also [Rect.center].
  Position center(Position origin) => Position(origin.dx + width / 2.0, origin.dy + height / 2.0);

  /// The position to the center of the right edge of the rectangle described by the
  /// given position (which is interpreted as the top-left corner) and this size.
  ///
  /// See also [Rect.centerLeft].
  Position centerRight(Position origin) => Position(origin.dx + width, origin.dy + height / 2.0);

  /// The position to the intersection of the bottom and left edges of the
  /// rectangle described by the given position (which is interpreted as the
  /// top-left corner) and this size.
  ///
  /// See also [Rect.bottomLeft].
  Position bottomLeft(Position origin) => Position(origin.dx, origin.dy + height);

  /// The position to the center of the bottom edge of the rectangle described by
  /// the given position (which is interpreted as the top-left corner) and this
  /// size.
  ///
  /// See also [Rect.bottomLeft].
  Position bottomCenter(Position origin) => Position(origin.dx + width / 2.0, origin.dy + height);

  /// The position to the intersection of the bottom and right edges of the
  /// rectangle described by the given position (which is interpreted as the
  /// top-left corner) and this size.
  ///
  /// See also [Rect.bottomRight].
  Position bottomRight(Position origin) => Position(origin.dx + width, origin.dy + height);

  /// Whether the point specified by the given position (which is assumed to be
  /// relative to the top left of the size) lies between the left and right and
  /// the top and bottom edges of a rectangle of this size.
  ///
  /// Rectangles include their top and left edges but exclude their bottom and
  /// right edges.
  bool contains(Position position) {
    return position.dx >= 0.0 && position.dx < width && position.dy >= 0.0 && position.dy < height;
  }

  /// A [Dimensions] with the [width] and [height] swapped.
  Dimensions get flipped => Dimensions(height, width);

  /// Linearly interpolate between two sizes
  ///
  /// The `t` argument represents position on the timeline, with 0.0 meaning
  /// that the interpolation has not started, returning `a` (or something
  /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
  /// returning `b` (or something equivalent to `b`), and values in between
  /// meaning that the interpolation is at the relevant point on the timeline
  /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
  /// 1.0, so negative values and values greater than 1.0 are valid (and can
  /// easily be generated by curves such as [Curves.elasticInOut]).
  ///
  /// Values for `t` are usually obtained from an [Animation<double>], such as
  /// an [AnimationController].
  static Dimensions lerp(Dimensions a, Dimensions b, double t) {
    return Dimensions(_lerpDouble(a.width, b.width, t), _lerpDouble(a.height, b.height, t));
  }

  /// Compares two Sizes for equality.
  // We don't compare the runtimeType because of _DebugSize in the framework.
  @override
  bool operator ==(Object other) {
    return other is Dimensions && other._dx == _dx && other._dy == _dy;
  }

  @override
  int get hashCode => Object.hash(_dx, _dy);

  @override
  String toString() => 'Size(${width.toStringAsFixed(1)}, ${height.toStringAsFixed(1)})';
}
