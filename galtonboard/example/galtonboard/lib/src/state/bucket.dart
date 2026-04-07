import 'package:common_collect/api.dart';
import 'package:common_event/api.dart';
import 'package:common_math/api.dart';

import 'sim_visual_params.dart';

class Buckets {
  Buckets(int numBuckets, EventBus eventBus) {
    _buckets = List.unmodifiable(List<int>.generate(numBuckets, (i) => i)
        .map((b) => Bucket(numBuckets, b, eventBus))
        .toList(growable: false));
  }

  late final List<Bucket> _buckets;

  List<Bucket> get bucketList => _buckets;

  List<int> get counts => _buckets.map((b) => b.count).toList(growable: false);

  Position midPointOfTop(int k, Dimensions size, SimVisualParams bvp) {
    return _buckets[k].dimensions(size, bvp).midPointOfBucketTop();
  }

  double width(Dimensions size, SimVisualParams bvp) {
    return _buckets[0].dimensions(size, bvp).width;
  }

  int get numBuckets => _buckets.length;
}

class BucketDimensions {
  BucketDimensions(
      {required this.width,
      required this.base,
      required this.sep,
      required this.height,
      required this.leftX});

  // width of bucket
  final double width;

  // base y coordinate
  final double base;

  // separation between buckets
  final double sep;

  // height of bucket
  final double height;

  // x-coordinate of left edge of the bucket
  final double leftX;

  late final Position leftBottom = Position(leftX, base);

  Position midPointOfBucketTop() {
    return Position(
      leftX + width / 2,
      base - height,
    );
  }

  Position midPointOfBottom() {
    return midPointOfBucketTop() + Vec2(0, height);
  }
}

class Bucket with FiresEventsMixin implements FiresEvents {
  Bucket(int numBuckets, this.b, EventBus eventBus) {
    this.eventBus = eventBus;
    N = numBuckets;
  }

  final int b;
  late final int N;
  final LastEntryCache2<Dimensions, SimVisualParams, BucketDimensions> _dimsCache =
      LastEntryCache2();

  // MUTABLE STATE //
  int count = 0;

  void increment() {
    // print("Incrementing bucket; current count = $count");
    count++;
    fireUpdateEvent();
  }

  BucketDimensions dimensions(Dimensions size, SimVisualParams bvp) {
    return _dimsCache.putIfAbsent(size, bvp, _dimensions);
  }

  BucketDimensions _dimensions(Dimensions size, SimVisualParams bvp) {
    final W = size.width - 2 * bvp.surroundSpace;
    final H = size.height - 2 * bvp.surroundSpace;
    final width = W / (N + (N + 1) * bvp.ratioSpaceBetweenBucketsToBucketWidth);
    final sep = width * bvp.ratioSpaceBetweenBucketsToBucketWidth;
    BucketDimensions dims = BucketDimensions(
      width: width,
      sep: sep,
      base: size.height - bvp.surroundSpace - (H * bvp.ratioBucketBaseToScreenHeight),
      height: (H * bvp.ratioBucketHeightToScreenHeight),
      leftX: bvp.surroundSpace + sep + (width + sep) * b,
    );
    return dims;
  }
}
