import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// Batches calls to canvas API's `drawRawAtlas` method. This method's benefit comes from reusing
/// bytebuffers without creating a ton of garbage and avoiding crossing the native barrier.
///
/// However, as it stands, the call-site has to
/// manage the bytebuffers itself which is problematic. In addition, WASM has some strange
/// limitations such as a maximum size of 2048 elements per call to `canvas.drawRawAtlas`. So,
/// use this class to both ergonomically manage the bytebuffers, avoid garbage and chunk the
/// `drawRawAtlas` calls into smaller, acceptable sized batches.
///
/// BUGS: Allocating memory 1, 2, 3, .. N exhausts WASM memory. So, we use a maxSize preallocation.
/// BUGS: Max batch size is 2048, 32KB (4Bytes * 4 entries per transform = 16B/transform).
///       Attempting to use a higher batch in a call to drawRawAtlas fails in WASM, but not in
///       Canvaskit.
class DrawAtlasBatcher {
  DrawAtlasBatcher(this.maxSize, this.batchSize);

  final int maxSize;
  final int batchSize;

  late final Float32List _rsTransformBuffer = Float32List(4 * maxSize);
  late final Float32List _rectBuffer = Float32List(4 * maxSize);
  late final List<RectFlattened> _rectFlats =
      List.generate(maxSize, (i) => RectFlattened(_rectBuffer, 4 * i));
  late final List<RsTransformFlattened> _rsTransformFlats =
      List.generate(maxSize, (i) => RsTransformFlattened(_rsTransformBuffer, 4 * i));

  void paint(int numElements, Canvas canvas, Image atlas, Paint paint) {
    for (int start = 0; start < numElements; start += batchSize) {
      int elements = min(batchSize, numElements - start);
      canvas.drawRawAtlas(
          atlas,
          Float32List.sublistView(_rsTransformBuffer, 4 * start, 4 * (start + elements)),
          Float32List.sublistView(_rectBuffer, 4 * start, 4 * (start + elements)),
          // colors
          null,
          // blendMode
          null,
          // cullRect
          null,
          paint);
    }
  }

  RsTransformFlattened rsTransform(int index) {
    return _rsTransformFlats[index];
  }

  RectFlattened rect(int index) {
    return _rectFlats[index];
  }
}

class RectFlattened {
  RectFlattened(this._backingList, this._startIndex);

  final Float32List _backingList;
  final int _startIndex;

  void setFromLTRB(double left, double top, double right, double bottom) {
    _backingList[_startIndex + 0] = left;
    _backingList[_startIndex + 1] = top;
    _backingList[_startIndex + 2] = right;
    _backingList[_startIndex + 3] = bottom;
  }
}

class RsTransformFlattened {
  RsTransformFlattened(this._backingList, this._startIndex);

  final Float32List _backingList;
  final int _startIndex;

  void setFromTranslate(double translateX, double translateY) {
    _backingList[_startIndex + 0] = 1;
    _backingList[_startIndex + 1] = 0;
    _backingList[_startIndex + 2] = translateX;
    _backingList[_startIndex + 3] = translateY;
  }
}
