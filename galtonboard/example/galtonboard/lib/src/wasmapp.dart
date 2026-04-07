import 'dart:math';

import 'package:flutter/material.dart';

// Sample app to test for memory leaks..
void runWasmParagraphApp() {
  final ThemeData themeData = ThemeData.light(useMaterial3: true);
  final ThemeData darkThemeData = ThemeData.dark(useMaterial3: true);
  final app = MaterialApp(
      theme: themeData.copyWith(
        sliderTheme: themeData.sliderTheme.copyWith(
          showValueIndicator: ShowValueIndicator.always,
        ),
      ),
      darkTheme: darkThemeData.copyWith(
        sliderTheme: darkThemeData.sliderTheme.copyWith(
          showValueIndicator: ShowValueIndicator.always,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const Scaffold(body: ParagraphApp()));
  runApp(app);
}

class ParagraphApp extends StatefulWidget {
  const ParagraphApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return ParagraphAppState();
  }
}

class ParagraphAppState extends State<ParagraphApp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _numLines = 10000;

  // Start off reusing paint.
  late bool _reusePaint = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 10000000,
      ),
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildCustomPainter();
  }

  Widget _buildCustomPainter() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Row(
          children: [
            const SizedBox(width: 150, child: Text("Number of lines")),
            Expanded(
              child: Slider(
                  value: _numLines,
                  min: 100,
                  max: 100000,
                  divisions: 1000,
                  label: _numLines.toStringAsFixed(0),
                  onChanged: (v) => {_numLines = v}),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 150, child: Text("Reuse Paint?")),
            Switch(
                value: _reusePaint,
                // activeColor: Colors.greenAccent,
                onChanged: (v) => {_reusePaint = v}),
          ],
        ),
        Expanded(
          child: Center(
              child: SizedBox(
                  height: double.infinity,
                  width: double.infinity,
                  child: CustomPaint(
                    foregroundPainter:
                        SimplePainter(numLines: _numLines.toInt(), reusePaint: _reusePaint),
                  ))),
        ),
      ],
    );
  }
}

class SimplePainter extends CustomPainter {

  SimplePainter({super.repaint, required this.numLines, required this.reusePaint});
  static final Random random = Random();
  static final Paint reusedPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.greenAccent
    ..strokeWidth = 1;

  static const double marginX = 10, marginY = 10;

  final int numLines;
  final bool reusePaint;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw numLines random lines each with a random line width style.
    double W = size.width - 2 * marginX;
    double H = size.height - 2 * marginY;
    for (int i = 0; i < numLines; i++) {
      double x1 = random.nextDouble() * W + marginX;
      double x2 = random.nextDouble() * W + marginX;
      double y1 = random.nextDouble() * H + marginY;
      double y2 = random.nextDouble() * H + marginY;
      canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          reusePaint ? reusedPaint : Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.greenAccent
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
