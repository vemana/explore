import 'package:common_state/api.dart';
import 'package:common_ui_widgets/api.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../state/flutter_state.dart';
import '../state/sim_visual_params.dart';
import '../state/simstate.dart';
import '../state/state.inject.names.dart' as names;
import 'bucket_painter.ui.dart';
import 'gate_painter.ui.dart';
import 'points_painter.ui.dart';
import 'theme/app_theme.dart';

@assistedFactory
abstract class SimStateViewFactory {
  SimStateView create({required SimState simState});
}

@assistedInject
class SimStateView implements HasWidget {
  SimStateView(
      {@assisted required this.simState,
      required this.appTheme,
      @names.showStatsParam required this.showStatsParam,
      @names.drawAtlasBatchSizeParam required this.drawAtlasBatchSizeParam});

  final SimState simState;
  final AppTheme appTheme;
  final Parameter<bool> showStatsParam;
  final Parameter<int> drawAtlasBatchSizeParam;
  late final SimVisualParams simVisualParams = SimVisualParams(simState.levels);

  @override
  Widget widget() {
    return Stack(
      key: ValueKey((
        simState.levels,
        simState.slotsPerLevelBits,
        simState.slotsIntoBucket,
        simState.probSuccess,
        simState.totalPoints,
      )),
      alignment: Alignment.topLeft,
      fit: StackFit.expand, // Pass tight, max, constraints to all children
      children: [
        // Buckets
        Container(
            color: Colors.black,
            child: SizedBox.expand(
              child: CustomPaint(
                foregroundPainter: BucketsPainter(
                  bucketCountStyle: appTheme.bucketCountStyle(),
                  buckets: simState.buckets,
                  simVisualParams: simVisualParams,
                  repaintOn: [appTheme, ...simState.buckets.bucketList],
                ),
              ),
            )),

        // Gates. No repaints needed since it is static for a given size. When sizes, this is
        // relaid out by Flutter.
        RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(
              size: const Size(double.infinity, double.infinity),
              willChange: false,
              isComplex: true,
              foregroundPainter: GatesPainter(simState.gates, simVisualParams),
            ),
          ),
        ),

        // Points (most expensive)
        guard(drawAtlasBatchSizeParam, () {
          return SizedBox.expand(
            child: CustomPaint(
              foregroundPainter: PointsPainter(
                  simState.points, simState.gates, simVisualParams, drawAtlasBatchSizeParam.val,
                  repaintOn: [simState]),
            ),
          );
        }),

        // Statistics
        Align(
          alignment: Alignment.topRight,
          child: guard(showStatsParam, () {
            return AnimatedOpacity(
              opacity: showStatsParam.val ? 1 : 0,
              duration: const Duration(seconds: 1),
              child: Container(
                margin: EdgeInsets.all(simVisualParams.surroundSpace.toDouble()),
                child: FractionallySizedBox(
                  widthFactor: 0.2,
                  heightFactor: 0.25,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: guard(appTheme, () {
                        return _buildTable(appTheme.metricsTextStyle);
                      }),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTable(TextStyle metricsTextStyle) {
    return guardMany([simState, drawAtlasBatchSizeParam], () {
      return Table(columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
      }, children: [
        _buildTableRow("Points simulated", simState.insertedPoints.toDouble(), metricsTextStyle),
        _buildTableRow("Points remaining", "${simState.remainingPoints}", metricsTextStyle),
        _buildTableRow("Frames", simState.simulatedFrames.toDouble(), metricsTextStyle),
        _buildTableRow("FPS (avg from begin)", simState.fps, metricsTextStyle),
        _buildTableRow("FPS (last ${SimState.numInstantaneousFpsFrames} frames)",
            simState.fpsInstantaneous, metricsTextStyle),
        _buildTableRow("Levels", simState.levels.toDouble(), metricsTextStyle),
        _buildTableRow(
            "Bias", "${(simState.probSuccess * 100).toStringAsFixed(0)}%", metricsTextStyle),
        _buildTableRow("Renderer", isRunningWithWasm ? "skwasm" : "canvaskit", metricsTextStyle),
        _buildTableRow("drawRawAtlas batch size", drawAtlasBatchSizeParam.val, metricsTextStyle),
      ]);
    });
  }

  TableRow _buildTableRow(String name, dynamic obj, TextStyle textStyle) {
    String metric = (obj is double) ? obj.toStringAsFixed(0) : obj.toString();
    return TableRow(children: [
      Text(
        name,
        style: textStyle,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          metric,
          style: textStyle,
        ),
      ),
    ]);
  }
}
