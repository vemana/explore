import 'dart:ui' as ui;

import 'package:common_math/api.dart' as sizes;
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';

import '../state/gate.dart';
import '../state/point.dart';
import '../state/points.dart';
import '../state/sim_visual_params.dart';

class PointsPainter extends RepaintableCustomPainter {
  PointsPainter(this.points, this.gates, this.visualParams, this.batchSize, {super.repaintOn});

  static final Paint pointPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke;

  static final Paint drawPointsPaint = Paint()
    ..color = Colors.red
    ..strokeCap = ui.StrokeCap.round
    ..style = PaintingStyle.stroke;

  final Points points;
  final SimVisualParams visualParams;
  final Gates gates;
  final int batchSize;
  late final DrawAtlasBatcher _batcher = DrawAtlasBatcher(_maxOutstandingPoints(), batchSize);
  late final DrawPointsBatcher _pointsBatcher = DrawPointsBatcher(_maxOutstandingPoints());

  int _maxOutstandingPoints() {
    final PointParams pointParams = points.pointParams;
    return pointParams.slotsPerLevel * pointParams.levels + pointParams.slotsIntoBucket + 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // paintOneByOne(canvas, size);
    paintUsingRawAtlas(canvas, size);
    // paintUsingDrawPoints(canvas, size);
  }

  void paintUsingDrawPoints(Canvas canvas, Size size) {
    int numPoints = points.points.length;
    if (numPoints == 0) return;

    final sizes.Dimensions ssize = size.to;
    final pointsGeometry = points.geometry(size.to, visualParams);
    double? radius;
    for (int i = 0; i < numPoints; i++) {
      Point p = points.points.elementAt(i);
      PointGeometry? geom = p.location(ssize, pointsGeometry, visualParams);
      if (geom == null) continue;
      radius ??= geom.radius;
      _pointsBatcher.point(i).setCoordinates(geom.center.dx, geom.center.dy);
    }
    _pointsBatcher.paint(
        numPoints,
        canvas,
        Paint()
          ..color = Colors.red
          ..style
          // ..strokeCap = ui.StrokeCap.round
          ..strokeWidth = radius!
          ..style = ui.PaintingStyle.stroke);
  }

  void paintUsingRawAtlas(Canvas canvas, Size size) {
    int numPoints = points.points.length;
    if (numPoints == 0) return;

    final sizes.Dimensions ssize = size.to;
    final pointsGeometry = points.geometry(size.to, visualParams);

    final (ui.Image atlas, ui.Picture picture) =
        _pointAsImage(size, pointsGeometry, points.points.elementAt(numPoints - 1));

    try {
      for (int i = 0; i < numPoints; i++) {
        Point p = points.points.elementAt(i);
        PointGeometry? geom = p.location(ssize, pointsGeometry, visualParams);
        if (geom == null) continue;
        _batcher
            .rsTransform(i)
            .setFromTranslate(geom.center.dx - geom.radius - 1, geom.center.dy - geom.radius - 1);
        _batcher.rect(i).setFromLTRB(0, 0, atlas.width.toDouble(), atlas.height.toDouble());
      }
      _batcher.paint(numPoints, canvas, atlas, pointPaint);
    } finally {
      atlas.dispose();
      picture.dispose();
    }
  }

  (ui.Image, ui.Picture) _pointAsImage(Size size, PointsGeometry geometry, Point point) {
    final PointGeometry pointGeometry = point.location(size.to, geometry, visualParams)!;
    final double radius = pointGeometry.radius;
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    canvas
        .clipRect(Rect.fromLTRB(0, 0, 2 * pointGeometry.radius + 2, 2 * pointGeometry.radius + 2));
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius, pointPaint);
    var picture = recorder.endRecording();
    return (picture.toImageSync(2 * radius.ceil() + 2, 2 * radius.ceil() + 2), picture);
  }

  void paintOneByOne(Canvas canvas, Size size) {
    final pointsGeometry = points.geometry(size.to, visualParams);
    for (var p in points.points) {
      paintPoint(canvas, size, p.location(size.to, pointsGeometry, visualParams));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  void paintPoint(Canvas canvas, Size size, PointGeometry? p) {
    if (p == null) return;
    canvas.drawCircle(p.center.to, p.radius, pointPaint);
  }
}
