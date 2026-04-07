import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';

import '../state/gate.dart';
import '../state/sim_visual_params.dart';

class GatesPainter extends CustomPainter {
  GatesPainter(this.gates, this.simVisualParams) {
    gatePainter = GatePainter();
  }

  final Gates gates;
  late final GatePainter gatePainter;
  final SimVisualParams simVisualParams;

  @override
  void paint(Canvas canvas, Size size) {
    for (var gatesList in gates.gatesMap) {
      for (var gate in gatesList) {
        gatePainter.paint(gate, canvas, size, simVisualParams);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class GatePainter {
  GatePainter();

  static final _gatePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  void paint(Gate gate, Canvas canvas, Size size, SimVisualParams simVisualParams) {
    GateDimensions dims = gate.dimensions(size.to, simVisualParams);
    canvas.drawCircle(dims.center.to, dims.radius, _gatePaint);
  }
}
