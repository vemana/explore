import 'dart:math';
import 'dart:ui' as ui;

import 'package:common_collect/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';

import '../state/bucket.dart';
import '../state/sim_visual_params.dart';

class BucketsPainter extends RepaintableCustomPainter {
  BucketsPainter(
      {required this.buckets,
      required this.bucketCountStyle,
      required this.simVisualParams,
      super.repaintOn});

  final Buckets buckets;
  final SimVisualParams simVisualParams;
  final TextStyle bucketCountStyle;
  late final List<BucketPainter> bps =
      buckets.bucketList.map((b) => BucketPainter(b, simVisualParams)).toList();

  @override
  void paint(Canvas canvas, Size size) {
    final bucketList = buckets.bucketList;
    int completedCount = bucketList.map((b) => b.count).reduce((x, y) => x + y);
    int maxCompleted = bucketList.map((b) => b.count).reduce((x, y) => max(x, y));
    for (var b in bps) {
      b.paint(
          canvas,
          size,
          bucketCountStyle,
          completedCount,
          maxCompleted,
          /*counts*/
          true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class BucketPainter {
  BucketPainter(this.b, this.bucketVisualParams);

  static final bucketFillPaint = Paint()
    ..color = Colors.greenAccent
    ..style = PaintingStyle.fill;

  static final bucketCountTextStyle = ui.TextStyle(
    color: Colors.greenAccent,
  );

  static final bucketCountTransform = Transform.flip(
    flipY: true,
  ).transform.storage;

  static final bucketOutlinePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  final Bucket b;
  final SimVisualParams bucketVisualParams;

  void paint(Canvas canvas, Size size, TextStyle textStyle, int completedCount, int maxCompleted,
      bool drawCount) {
    BucketDimensions dims = b.dimensions(size.to, bucketVisualParams);
    BucketOutlines outlines = _getOutlines(size, textStyle);

    canvas.drawPath(outlines.bucketOutlinePath, bucketOutlinePaint);

    double completedPct = 0;
    if (maxCompleted > 0) {
      completedPct = 100 * (b.count.toDouble()) / completedCount;
      double H = (b.count.toDouble()) / maxCompleted * dims.height;
      // This could be a GC hotspot
      canvas.drawRect(Rect.fromLTWH(dims.leftX, dims.base - H, dims.width, H), bucketFillPaint);
    }

    // Print the count.
    if (drawCount) _drawCount(dims, outlines, canvas, size, completedPct);
  }

  void _drawCount(BucketDimensions dims, BucketOutlines outlines, Canvas canvas, Size size,
      double completedPct) {
    // Flip the text so that we can use our coordinate system of screen bottom being 0  y-coord.
    var paragraph = (ui.ParagraphBuilder(outlines.bucketCountStyle)
          ..pushStyle(bucketCountTextStyle)
          ..addText("${completedPct.toStringAsFixed(1)}%"))
        .build()
      ..layout(outlines.bucketCountConstraints);
    canvas.drawParagraph(paragraph, dims.leftBottom.to);
    paragraph.dispose(); // This is a native element and should be disposed.
  }

  final dimsCache = LastEntryCache<(Size, TextStyle), BucketOutlines>();

  BucketOutlines _getOutlines(Size size, TextStyle textStyle) {
    return dimsCache.putIfAbsent((size, textStyle), _getOutlines2);
  }

  BucketOutlines _getOutlines2((Size, TextStyle) r) {
    Size size = r.$1;
    TextStyle textStyle = r.$2;

    BucketDimensions dims = b.dimensions(size.to, bucketVisualParams);

    final bucketOutlinePath = Path()
      ..moveTo(dims.leftX, dims.base - dims.height)
      ..lineTo(dims.leftX, dims.base)
      ..lineTo(dims.leftX + dims.width, dims.base)
      ..lineTo(dims.leftX + dims.width, dims.base - dims.height);

    final double bucketCountFontSize = min(15, dims.width);

    BucketOutlines outlines = BucketOutlines(
      size: size,
      bucketOutlinePath: bucketOutlinePath,
      bucketCountFontSize: bucketCountFontSize,
      bucketCountStyle: ui.ParagraphStyle(
        fontWeight: textStyle.fontWeight!,
        fontSize: bucketCountFontSize,
        fontFamily: textStyle.fontFamily!,
        textAlign: ui.TextAlign.center,
      ),
      bucketCountConstraints: ui.ParagraphConstraints(width: dims.width),
    );

    return outlines;
  }
}

class BucketOutlines {
  BucketOutlines(
      {required this.size,
      required this.bucketOutlinePath,
      required this.bucketCountFontSize,
      required this.bucketCountStyle,
      required this.bucketCountConstraints});

  final Size size;
  final Path bucketOutlinePath;
  final double bucketCountFontSize;
  final ui.ParagraphStyle bucketCountStyle;
  final ui.ParagraphConstraints bucketCountConstraints;
}
