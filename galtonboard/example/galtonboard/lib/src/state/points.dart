import 'dart:collection';

import 'package:common_collect/api.dart';

import 'package:common_math/api.dart';
import 'bucket.dart';
import 'gate.dart';
import 'point.dart';
import 'sim_visual_params.dart';

class Points {
  Points(
      {required this.probSuccess,
      required this.buckets,
      required this.numLevels,
      required this.slotsPerLevelBits,
      required this.slotsIntoBucket,
      required this.gates})
      : points = ListQueue();

  final ListQueue<Point> points;
  late final int slotsPerLevel = (1 << slotsPerLevelBits);
  final int slotsPerLevelBits;
  final int numLevels;
  final int slotsIntoBucket;
  final double probSuccess;
  final Buckets buckets;
  final Gates gates;
  late final pointParams = PointParams(
      probSuccess: probSuccess,
      buckets: buckets,
      gatesMap: gates.gatesMap,
      slotsPerLevelBits: slotsPerLevelBits,
      levels: numLevels,
      slotsIntoBucket: slotsIntoBucket);

  late final LastEntryCache2<Dimensions, SimVisualParams, PointsGeometry> pointsGeometryCache =
      LastEntryCache2();

  /// add points & simulate. Return the number of non-done points.
  int simulate(int newPoints, int advanceBy) {
    if (newPoints > advanceBy) {
      throw ArgumentError("newPoints should be <= slotsPerLevel");
    }

    for (int i = 0; i < newPoints; i++) {
      points.add(Point(slotNumber: -i, params: pointParams));
    }

    for (int i = 0; i < points.length;) {
      int bucket = points.elementAt(i).advance(advanceBy);
      if (bucket >= 0) {
        if (i != 0) throw StateError("i should be 0");
        points.removeFirst();
        buckets.bucketList[bucket].increment();
      } else {
        i++;
      }
    }

    return points.length;
  }

  PointsGeometry geometry(Dimensions size, SimVisualParams visualParams) {
    return pointsGeometryCache.putIfAbsent(size, visualParams, _geometry);
  }

  PointsGeometry _geometry(Dimensions size, SimVisualParams visualParams) {
    double pointRadius = 0;
    if (points.isNotEmpty) {
      pointRadius = points.first.pointRadius(size, visualParams);
    }
    return PointsGeometry(size, gates.geometry(size, visualParams), slotsPerLevel, pointRadius);
  }
}

class PointsGeometry {
  PointsGeometry(this.size, GatesGeometry gg, int slotsPerLevel, double pointRadius)
      : firstGateCenter = gg.firstGateCenter,
        gateRadius = gg.gateRadius {
    double slotLength = (gg.left.length() - 2 * (pointRadius + gateRadius)) / (slotsPerLevel - 1);
    _dirGeometries = [
      _DirGeometry(
        segment: gg.left,
        segmentUnit: gg.left.unit(),
        slotUnit: gg.left.unit() * slotLength,
      ),
      _DirGeometry(
        segment: gg.right,
        segmentUnit: gg.right.unit(),
        slotUnit: gg.right.unit() * slotLength,
      ),
    ];
  }

  final Dimensions size;

  late final List<_DirGeometry> _dirGeometries;

  /// Center of the topmost gate
  final Position firstGateCenter;

  /// Radius of each gate
  final double gateRadius;

  Vec2 segment(int dir) {
    return _dirGeometries[dir].segment;
  }

  Vec2 segmentUnit(int dir) {
    return _dirGeometries[dir].segmentUnit;
  }

  Vec2 slotUnit(int dir) {
    return _dirGeometries[dir].slotUnit;
  }
}

class _DirGeometry {
  _DirGeometry({required this.segment, required this.segmentUnit, required this.slotUnit});

  /// Distance between gates
  Vec2 segment;

  /// segment.unit()
  Vec2 segmentUnit;

  /// A single slot's distance along left (or right). A slot-segment consists of (slotsPerLevel - 1)
  /// slots. A slot-segment starts at the first point's position on the segment and ends at the
  /// last point's position on  the segment. That's why it has (slotsPerLevel - 1) slots and not
  /// slotsPerLevel slots.
  Vec2 slotUnit;
}
