import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:common_collect/api.dart';

import 'package:common_math/api.dart';
import 'bucket.dart';
import 'sim_visual_params.dart';

class GatesGeometry {
  GatesGeometry(this.firstGateCenter, this.gateRadius, this.left, this.right);

  // Distance between gates in the left direction.
  final Vec2 left;

  // Distance between gates in the right direction.
  final Vec2 right;

  // Center point of the first gate.
  final Position firstGateCenter;

  final double gateRadius;
}

class Gates {
  Gates({required this.buckets, required int levels}) {
    gatesMap = BuiltList.build((outer) {
      for (int level = 0; level < levels; level++) {
        outer.add(BuiltList<Gate>.from(
            Iterable.generate(level + 1, (i) => Gate(level: level, index: i, buckets: buckets))));
      }
    });
  }

  final Buckets buckets;
  late final BuiltList<BuiltList<Gate>> gatesMap;

  GatesGeometry geometry(Dimensions size, SimVisualParams visualParams) {
    GateDimensions one = gatesMap[0].first.dimensions(size, visualParams);
    GateDimensions two = gatesMap[1][0].dimensions(size, visualParams);
    GateDimensions three = gatesMap[1][1].dimensions(size, visualParams);
    return GatesGeometry(
        one.center, one.radius, two.center - one.center, three.center - one.center);
  }
}

class GateDimensions {
  GateDimensions(this.center, this.radius);

  final Position center;
  final double radius;
}

class Gate {
  /// Use the params object to reduce memory pressure. Params is constant across each gate.
  /// So, instead of flattening it out in the constructor here, reuse a single instance.
  Gate({
    required this.level,
    required this.index,
    required this.buckets,
  });

  /// Gate is [index]th from left at level [level]. Levels start numbering at 0.
  final int level;
  final int index;
  final Buckets buckets;

  LastEntryCache2<Dimensions, SimVisualParams, GateDimensions> dimsCache = LastEntryCache2();

  GateDimensions dimensions(Dimensions size, SimVisualParams simVisualParams) {
    return dimsCache.putIfAbsent(size, simVisualParams, _dimensions);
  }

  GateDimensions _dimensions(Dimensions size, SimVisualParams svParams) {
    final H = size.height - 2 * svParams.surroundSpace;

    double widthSep =
        (buckets.midPointOfTop(1, size, svParams) - buckets.midPointOfTop(0, size, svParams)).dx;
    double heightSep = svParams.ratioLevelSeparationToHeight * H;

    int levels = buckets.numBuckets;
    double Y = buckets.midPointOfTop(0, size, svParams).dy - (levels - level) * heightSep;
    int k = (levels - level) ~/ 2;
    final Position firstTopMid = buckets.midPointOfTop(k, size, svParams);
    double X = firstTopMid.dx;
    if (level % 2 == levels % 2) {
      final secondTopMid = buckets.midPointOfTop(k - 1, size, svParams);
      X = Position.lerp(firstTopMid, secondTopMid, 0.5)!.dx;
    }
    X += index * widthSep;
    final center = Position(X, Y);
    // r + y < size.height - surroundspace to avoid canvas overflow
    final radius = min(min(svParams.ratioGateRadiusToHeight * H, buckets.width(size, svParams)),
        size.height - svParams.surroundSpace - Y);

    return GateDimensions(center, radius);
  }
}
