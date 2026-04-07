import 'dart:math';

import 'position_dimensions.dart';

class Vec2 {
  Vec2(this.dx, this.dy);

  Vec2.fromOffset(Position offset)
      : dx = offset.dx,
        dy = offset.dy;

  late final double dx;
  late final double dy;

  Vec2 unit() {
    return Vec2(dx / length(), dy / length());
  }

  double length() {
    return sqrt(lengthSquared());
  }

  double lengthSquared() {
    return dx * dx + dy * dy;
  }

  Position toOffset() {
    return Position(dx, dy);
  }

  Vec2 operator -(Vec2 other) => Vec2(dx - other.dx, dy - other.dy);

  Vec2 operator +(Vec2 other) => Vec2(dx + other.dx, dy + other.dy);

  Vec2 operator *(num operand) => Vec2(dx * operand.toDouble(), dy * operand.toDouble());

  Vec2 operator /(num operand) => Vec2(dx / operand.toDouble(), dy / operand.toDouble());

  @override
  String toString() {
    return 'Vec2($dx, $dy)';
  }
}
