import 'dart:collection';
import 'dart:math';

import 'package:common_base/api.dart';
import 'package:common_event/api.dart';
import 'package:common_ui_widgets/api.dart';

import 'bucket.dart';
import 'gate.dart';
import 'points.dart';

enum SimControlState {
  running,
  paused,
  completed,
}

class SimState with FiresEventsMixin implements FiresEvents {
  SimState({
    required this.levels,
    required this.slotsPerLevelBits,
    required this.slotsIntoBucket,
    required this.probSuccess,
    required this.totalPoints,
    required this.tickNotifier,
    required int slotsPerFrame,
    required eventBus,
  }) : _slotsPerFrame = slotsPerFrame {
    this.eventBus = eventBus;
    _init();
  }

  static const int numInstantaneousFpsFrames = 100;

  final int levels;
  final int slotsPerLevelBits;
  final int slotsIntoBucket;
  final double probSuccess;
  final int totalPoints;
  final TickNotifier tickNotifier;
  int _slotsPerFrame;

  set slotsPerFrame(int value) {
    _slotsPerFrame = value;
  }

  // State params
  late final Buckets _buckets;
  late final Gates _gates;
  late final Points _points;
  late final Stopwatch stopwatch;
  final ListQueue<double> _frameTimestamps = ListQueue(numInstantaneousFpsFrames);

  // MUTABLE STATE //
  double _fpsInstantaneous = 0;
  late int _remainingPoints;
  late int _insertedPoints;
  late int _simulatedFrames;
  late double _fps;
  late SimControlState _simControlState;

  Buckets get buckets => _buckets;

  int get insertedPoints => _insertedPoints;

  Gates get gates => _gates;

  Points get points => _points;

  int get remainingPoints => _remainingPoints;

  int get simulatedFrames => _simulatedFrames;

  double get fps => _fps;

  double get fpsInstantaneous => _fpsInstantaneous;

  bool get isCompleted => _simControlState == SimControlState.completed;

  SimControlState get state => _simControlState;

  void _init() {
    // Create Buckets
    _buckets = Buckets(levels, eventBus);

    // Create Gates
    _gates = Gates(buckets: _buckets, levels: levels);

    // Create Points
    _points = Points(
      probSuccess: probSuccess,
      buckets: _buckets,
      gates: _gates,
      numLevels: levels,
      slotsPerLevelBits: slotsPerLevelBits,
      slotsIntoBucket: slotsIntoBucket,
    );

    _remainingPoints = totalPoints;
    _insertedPoints = 0;
    _simulatedFrames = 0;
    _fps = 0;

    // Start the simulation
    tickNotifier.addListener(_onTick);
    tickNotifier.start();
    _simControlState = SimControlState.running;
  }

  void pause() {
    assertState(_simControlState == SimControlState.running, "Cannot pause $_simControlState");
    tickNotifier.pause();
    _simControlState = SimControlState.paused;
    fireUpdateEvent();
  }

  void resume() {
    assertState(_simControlState != SimControlState.completed, "Cannot resume $_simControlState.");
    tickNotifier.start();
    _simControlState = SimControlState.running;
    fireUpdateEvent();
  }

  void dispose() {
    tickNotifier.pause();
    tickNotifier.removeListener(_onTick);
    // release memory for _points, _gates, _buckets etc. But, that's done by just nulling out this
    // reference(simState) as a whole by the caller.
  }

  void _onTick() {
    _simulateMovement();
    if (isCompleted) {
      tickNotifier.pause();
    }
    fireUpdateEvent();
  }

  void _computeInstantaneousFps(int timestampMicros) {
    double first = 0;
    if (_frameTimestamps.length == numInstantaneousFpsFrames) {
      first = _frameTimestamps.removeFirst();
    }
    _frameTimestamps.addLast(timestampMicros.toDouble());
    _fpsInstantaneous = _frameTimestamps.length * 1000000.0 / (timestampMicros - first);
  }

  void _simulateMovement() {
    if (_simControlState == SimControlState.completed) {
      return;
    }

    if (_simulatedFrames == 0) {
      stopwatch = Stopwatch()..start();
    } else {
      _fps = _simulatedFrames * 1000000 / stopwatch.elapsed.inMicroseconds;
    }
    _computeInstantaneousFps(stopwatch.elapsed.inMicroseconds);

    int currentPointsInFrame = min(_remainingPoints, _slotsPerFrame);
    _remainingPoints -= currentPointsInFrame;
    _insertedPoints += currentPointsInFrame;
    _simulatedFrames++;

    int nonDonePoints = _points.simulate(currentPointsInFrame, _slotsPerFrame);
    if (nonDonePoints == 0 && _remainingPoints == 0) {
      _simControlState = SimControlState.completed;
    }
  }
}
