import 'dart:math';

import 'package:built_collection/built_collection.dart';

import 'package:common_math/api.dart';
import 'bucket.dart';
import 'gate.dart';
import 'points.dart';
import 'sim_visual_params.dart';
import 'simcontrol.dart';

var rand = Random();
// var xrand = Xrandom();

class PointParams {
  PointParams(
      {required this.buckets,
      required this.slotsPerLevelBits,
      required this.levels,
      required this.slotsIntoBucket,
      required this.probSuccess,
      required this.gatesMap});

  late final int slotsPerLevel = (1 << SimStateController.slotsPerLevelBits);
  final int slotsPerLevelBits;
  final int levels;
  final int slotsIntoBucket;
  final double probSuccess;
  final BuiltList<BuiltList<Gate>> gatesMap; // can be converted to List<List<>>
  final Buckets buckets;
}

typedef PointsVec2 = Position;

class Point {
  /// Use the params object to reduce memory pressure. Params is constant across each point.
  /// So, instead of flattening it out in the constructor here, reuse a single instance.
  Point({required this.slotNumber, required this.params}) {
    if (slotNumber > 0) {
      throw ArgumentError("slotNumber should be <= 0");
    }
  }

  int slotNumber;

  final PointParams params;

  // The point is going in direction 'direction' (0 for left, 1 for right)
  late int _direction = -1;

  // The number of rights this point took so far
  late int _numHeads = 0;

  // The next level we'll encounter [0 numLevels-1]. When we encounter numLevels-1, it's over.
  late int _level = 0;

  // Are we out of all trials and entering the bucket
  // if true, levels = levels
  late bool _nearBucket = false;

  // The in-bucket slot number (only valid when _nearBucket)
  late int _nearBucketSlot = 0;

  // Are we done; i.e. completed trials & entered bucket.
  // if true, level = levels
  late bool _complete = false;

  /// Returns a value >=0 if completed, signifiying the number of heads.
  /// Otherwise, <0.
  int advance(int slots) {
    if (_complete) {
      throw StateError("Already completed");
    }

    slotNumber += slots;
    if (slotNumber <= 0) {
      throw StateError("slotNumber <= 0 after advance. Something's wrong.");
    }

    // First do any remaining trials.
    int newLevel = _getTrials(slotNumber);
    if (newLevel > _level) {
      int rem = newLevel - _level;
      for (int i = 0; i < rem; i++) {
        // Consider: Use the faster, lower precision xrand.nextFloat() over rand.nextDouble()
        _direction = (rand.nextDouble() < params.probSuccess) ? 1 : 0;
        _numHeads += _direction;
      }
      _level = newLevel;
    }

    int maxSlotNumber = params.slotsPerLevel * (params.levels - 1) + params.slotsIntoBucket;
    // Check where we are.
    if (slotNumber > maxSlotNumber) {
      _complete = true;
      _nearBucket = false;
      _level = params.levels;
      return _numHeads;
    }

    if (slotNumber > params.slotsPerLevel * (params.levels - 1)) {
      _nearBucket = true;
      _nearBucketSlot = slotNumber - params.slotsPerLevel * (params.levels - 1);
      _level = params.levels;
    }

    // _level < levels & index/direction are valid.
    return -1;
  }

  int _getTrials(int slot) {
    if (slot <= 0) {
      return 0;
    }
    int trials = ((slot - 1) ~/ params.slotsPerLevel) + 1;
    if (trials > params.levels - 1) trials = params.levels - 1;
    return trials;
  }

  @override
  String toString() {
    return "Point(slot = $slotNumber, heads = $_numHeads, level = $_level, direction = "
        "$_direction, "
        "nearBucket"
        " = "
        "$_nearBucket, complete = $_complete)";
  }

  double pointRadius(Dimensions size, SimVisualParams visualParams) {
    return visualParams.ratioPointRadiusToHeight * (size.height - 2 * visualParams.surroundSpace);
  }

  PointGeometry? location(Dimensions size, PointsGeometry geometry, SimVisualParams visualParams) {
    double radius = pointRadius(size, visualParams);

    // Determine the location as a linear interpolation
    // Use L slots between circles A & B.
    if (slotNumber <= 0) {
      // before level 0
      throw StateError("Unexpected: Point with slot number <= 0");
    } else if (_nearBucket) {
      // Use the uncached slowpath since the number of points that fall here is
      // fps * slotsPerFrame < 60 * 40 = 2400/sec, a negligible number.
      // And trying to include this in caching would be unweildy.
      final GateDimensions gateDims =
          params.gatesMap[params.levels - 1][_numHeads].dimensions(size, visualParams);
      double gateRadius = gateDims.radius;
      Position gateCenter = gateDims.center;
      Position bottom =
          params.buckets.bucketList[_numHeads].dimensions(size, visualParams).midPointOfBottom() +
              Vec2(0, -radius);
      Position first = gateCenter + ((bottom - gateCenter).unit()) * (gateRadius + radius);
      var dv = (bottom - first) / (params.slotsIntoBucket - 1);
      return PointGeometry(radius, first + (dv) * (_nearBucketSlot - 1));
    } else if (_complete) {
      // Nothing to paint for a completed point.
      return null;
    } else {
      assert(_level > 0);
      assert(geometry.size == size);

      int idx = ((slotNumber - 1) & ((1 << params.slotsPerLevelBits) - 1)) + 1;
      Position gateCenter = geometry.firstGateCenter +
          geometry.segment(0) * (_level - 1 - (_numHeads - _direction)) +
          geometry.segment(1) * (_numHeads - _direction);
      Position first =
          gateCenter + geometry.segmentUnit(_direction) * (geometry.gateRadius + radius);
      Position pointCenter = first + geometry.slotUnit(_direction) * (idx - 1);
      return PointGeometry(radius, pointCenter);
    }
  }
}

class PointGeometry {
  PointGeometry(this.radius, this.center);

  final double radius;
  final Position center;
}
