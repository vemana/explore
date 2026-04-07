import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// Batches calls to canvas API's `drawRawPoints` method. This method's benefit comes from reusing
/// bytebuffers without creating a ton of garbage. However, as it stands, the call-site has to
/// manage the bytebuffers itself which is problematic. In addition, WASM has some strange
/// limitations such as a maximum size of 2048 elements per call to `canvas.drawRawPoints`. So,
/// use this class to both ergonomically manage the bytebuffers, avoid garbage and chunk the
/// `drawRawPoints` calls into smaller, acceptable sized batches.
class DrawPointsBatcher {
  DrawPointsBatcher(this.maxSize);

  final int maxSize;

  late final Float32List _pointsBuffer = Float32List(2 * maxSize);
  late final List<PointFlattened> _pointFlats =
      List.generate(maxSize, (i) => PointFlattened(_pointsBuffer, 2 * i));

  void paint(int numElements, Canvas canvas, Paint paint) {
    int batchSize = 2048;
    for (int start = 0; start < numElements; start += batchSize) {
      int elements = min(batchSize, numElements - start);
      canvas.drawRawPoints(PointMode.points,
          Float32List.sublistView(_pointsBuffer, 2 * start, 2 * (start + elements)), paint);
    }
  }

  PointFlattened point(int index) {
    return _pointFlats[index];
  }
}

class PointFlattened {
  PointFlattened(this._backingList, this._startIndex);

  final Float32List _backingList;
  final int _startIndex;

  void setCoordinates(double x, double y) {
    _backingList[_startIndex + 0] = x;
    _backingList[_startIndex + 1] = y;
  }
}
