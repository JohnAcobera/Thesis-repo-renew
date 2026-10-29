import 'package:flutter/material.dart';

enum LearningMetricChartKind { line, bars, diverging, activity }

class LearningMetricChartPainter extends CustomPainter {
  const LearningMetricChartPainter({
    required this.samples,
    required this.kind,
    required this.color,
  });

  final List<double> samples;
  final LearningMetricChartKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final baseline = size.height - 2;
    final basePaint = Paint()
      ..color = const Color(0xFFE8D7C2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      basePaint,
    );
    if (samples.isEmpty) {
      canvas.restore();
      return;
    }

    switch (kind) {
      case LearningMetricChartKind.line:
        _paintLine(canvas, size);
      case LearningMetricChartKind.bars:
        _paintBars(canvas, size, diverging: false);
      case LearningMetricChartKind.diverging:
        _paintBars(canvas, size, diverging: true);
      case LearningMetricChartKind.activity:
        _paintActivity(canvas, size);
    }
    canvas.restore();
  }

  void _paintLine(Canvas canvas, Size size) {
    final points = _normalizedPoints(size, samples, 0, 100);
    if (points.length == 1) {
      canvas.drawCircle(points.first, 2.5, Paint()..color = color);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 2, Paint()..color = color);
    }
  }

  void _paintBars(Canvas canvas, Size size, {required bool diverging}) {
    final count = samples.length;
    const gap = 3.0;
    final barWidth = (size.width - gap * (count - 1)) / count;
    final zeroY = diverging ? size.height / 2 : size.height - 2;
    if (diverging) {
      canvas.drawLine(
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = const Color(0xFFCAB6A5)
          ..strokeWidth = 1,
      );
    }
    for (var index = 0; index < count; index++) {
      final sample = samples[index];
      final normalized = diverging
          ? sample.clamp(-100.0, 100.0) / 100
          : sample.clamp(0.0, 100.0) / 100;
      final availableHeight = diverging ? size.height / 2 - 2 : size.height - 2;
      final barHeight = (normalized.abs() * availableHeight).clamp(
        2.0,
        availableHeight,
      );
      final left = index * (barWidth + gap);
      final top = diverging
          ? normalized > 0
                ? zeroY - barHeight
                : zeroY
          : zeroY - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: 0.82),
      );
    }
  }

  void _paintActivity(Canvas canvas, Size size) {
    const gap = 1.5;
    final barWidth = (size.width - gap * (samples.length - 1)) / samples.length;
    for (var index = 0; index < samples.length; index++) {
      final active = samples[index] > 0;
      final left = index * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            active ? size.height * 0.35 : size.height * 0.78,
            barWidth,
            active ? size.height * 0.65 - 2 : size.height * 0.22,
          ),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = active
              ? color.withValues(alpha: 0.88)
              : color.withValues(alpha: 0.16),
      );
    }
  }

  List<Offset> _normalizedPoints(
    Size size,
    List<double> values,
    double minimum,
    double maximum,
  ) {
    if (values.length == 1) {
      return [
        Offset(
          size.width / 2,
          size.height - 2 - (values.first / maximum) * (size.height - 4),
        ),
      ];
    }
    return List<Offset>.generate(values.length, (index) {
      final x = size.width * index / (values.length - 1);
      final normalized =
          ((values[index].clamp(minimum, maximum) - minimum) /
                  (maximum - minimum))
              .toDouble();
      return Offset(x, size.height - 2 - normalized * (size.height - 4));
    });
  }

  @override
  bool shouldRepaint(covariant LearningMetricChartPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.kind != kind ||
      oldDelegate.color != color;
}
