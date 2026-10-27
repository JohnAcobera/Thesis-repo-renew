import 'dart:math' as math;

import 'package:flutter/material.dart';

class StudentPerformanceRadarChart extends StatelessWidget {
  const StudentPerformanceRadarChart({
    required this.accuracyPercentage,
    required this.retentionPercentage,
    required this.improvementPercentage,
    required this.consistencyPercentage,
    required this.focusPercentage,
    this.gridColor = const Color(0xFFD4C7BA),
    this.accentColor = const Color(0xFFE8753D),
    this.labelColor = const Color(0xFF574438),
    this.showWeeklySeries = false,
    this.weeklyAccuracyPercentage,
    this.weeklyRetentionPercentage,
    this.weeklyImprovementPercentage,
    this.weeklyConsistencyPercentage,
    this.weeklyFocusPercentage,
    this.weeklyColor = const Color(0xFF8064A2),
    super.key,
  });

  final double? accuracyPercentage;
  final double? retentionPercentage;
  final double? improvementPercentage;
  final double? consistencyPercentage;
  final double? focusPercentage;
  final Color gridColor;
  final Color accentColor;
  final Color labelColor;
  final bool showWeeklySeries;
  final double? weeklyAccuracyPercentage;
  final double? weeklyRetentionPercentage;
  final double? weeklyImprovementPercentage;
  final double? weeklyConsistencyPercentage;
  final double? weeklyFocusPercentage;
  final Color weeklyColor;

  static const _metrics = [
    'Accuracy',
    'Retention',
    'Improvement',
    'Consistency',
    'Focus',
  ];

  @override
  Widget build(BuildContext context) {
    final chart = CustomPaint(
      painter: _StudentPerformanceRadarPainter(
        accuracyPercentage: accuracyPercentage,
        retentionPercentage: retentionPercentage,
        improvementPercentage: improvementPercentage,
        consistencyPercentage: consistencyPercentage,
        focusPercentage: focusPercentage,
        weeklyAccuracyPercentage: weeklyAccuracyPercentage,
        weeklyRetentionPercentage: weeklyRetentionPercentage,
        weeklyImprovementPercentage: weeklyImprovementPercentage,
        weeklyConsistencyPercentage: weeklyConsistencyPercentage,
        weeklyFocusPercentage: weeklyFocusPercentage,
        showWeeklySeries: showWeeklySeries,
        gridColor: gridColor,
        accentColor: accentColor,
        labelColor: labelColor,
        weeklyColor: weeklyColor,
      ),
      child: const SizedBox.expand(),
    );
    if (!showWeeklySeries) return chart;

    return Column(
      children: [
        Expanded(child: chart),
        SizedBox(
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: accentColor, label: 'Current stats'),
              const SizedBox(width: 14),
              _LegendItem(color: weeklyColor, label: 'Past 7 days'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 2, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF574438),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _StudentPerformanceRadarPainter extends CustomPainter {
  const _StudentPerformanceRadarPainter({
    required this.accuracyPercentage,
    required this.retentionPercentage,
    required this.improvementPercentage,
    required this.consistencyPercentage,
    required this.focusPercentage,
    required this.weeklyAccuracyPercentage,
    required this.weeklyRetentionPercentage,
    required this.weeklyImprovementPercentage,
    required this.weeklyConsistencyPercentage,
    required this.weeklyFocusPercentage,
    required this.showWeeklySeries,
    required this.gridColor,
    required this.accentColor,
    required this.labelColor,
    required this.weeklyColor,
  });

  final double? accuracyPercentage;
  final double? retentionPercentage;
  final double? improvementPercentage;
  final double? consistencyPercentage;
  final double? focusPercentage;
  final double? weeklyAccuracyPercentage;
  final double? weeklyRetentionPercentage;
  final double? weeklyImprovementPercentage;
  final double? weeklyConsistencyPercentage;
  final double? weeklyFocusPercentage;
  final bool showWeeklySeries;
  final Color gridColor;
  final Color accentColor;
  final Color labelColor;
  final Color weeklyColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (StudentPerformanceRadarChart._metrics.isEmpty || size.isEmpty) return;

    final metrics = StudentPerformanceRadarChart._metrics;
    final center = Offset(size.width / 2, size.height / 2);
    final heightPadding = showWeeklySeries ? 54 : 72;
    final radius = math.min(
      (size.width - 116) / 2,
      (size.height - heightPadding) / 2,
    );
    if (radius <= 0) return;

    final angles = List<double>.generate(
      metrics.length,
      (index) => -math.pi / 2 + (2 * math.pi * index / metrics.length),
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= 4; level++) {
      final levelRadius = radius * level / 4;
      final path = Path();
      for (var index = 0; index < angles.length; index++) {
        final point = Offset(
          center.dx + math.cos(angles[index]) * levelRadius,
          center.dy + math.sin(angles[index]) * levelRadius,
        );
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (final angle in angles) {
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        gridPaint,
      );
    }

    final metricValues = [
      accuracyPercentage,
      retentionPercentage,
      improvementPercentage == null
          ? null
          : (improvementPercentage! + 100).clamp(0.0, 200.0) / 2,
      consistencyPercentage,
      focusPercentage,
    ];
    final weeklyMetricValues = [
      weeklyAccuracyPercentage,
      weeklyRetentionPercentage,
      weeklyImprovementPercentage == null
          ? null
          : (weeklyImprovementPercentage! + 100).clamp(0.0, 200.0) / 2,
      weeklyConsistencyPercentage,
      weeklyFocusPercentage,
    ];

    List<Offset> pointsFor(List<double?> values) =>
        List<Offset>.generate(metrics.length, (index) {
          final value = values[index] ?? 0.0;
          final normalizedValue = value.clamp(0.0, 100.0) / 100;
          return Offset(
            center.dx + math.cos(angles[index]) * radius * normalizedValue,
            center.dy + math.sin(angles[index]) * radius * normalizedValue,
          );
        });

    Path pathFor(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path..close();
    }

    void drawFill(
      List<double?> values,
      List<Offset> points,
      Color color,
      double opacity,
    ) {
      if (!values.any((value) => value != null)) return;
      canvas.drawPath(
        pathFor(points),
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );
    }

    void drawOutline(List<double?> values, List<Offset> points, Color color) {
      if (!values.any((value) => value != null)) return;
      canvas.drawPath(
        pathFor(points),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    void drawMarkers(List<double?> values, List<Offset> points, Color color) {
      for (var index = 0; index < points.length; index++) {
        if (values[index] == null) continue;
        canvas.drawCircle(
          points[index],
          3,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      }
    }

    final metricPoints = pointsFor(metricValues);
    final weeklyMetricPoints = pointsFor(weeklyMetricValues);
    if (showWeeklySeries) {
      drawFill(weeklyMetricValues, weeklyMetricPoints, weeklyColor, 0.14);
    }
    drawFill(metricValues, metricPoints, accentColor, 0.2);
    if (showWeeklySeries) {
      drawOutline(weeklyMetricValues, weeklyMetricPoints, weeklyColor);
    }
    drawOutline(metricValues, metricPoints, accentColor);
    if (showWeeklySeries) {
      drawMarkers(weeklyMetricValues, weeklyMetricPoints, weeklyColor);
    }
    drawMarkers(metricValues, metricPoints, accentColor);

    for (var index = 0; index < metrics.length; index++) {
      final angle = angles[index];
      final label = TextPainter(
        text: TextSpan(
          text: metrics[index],
          style: TextStyle(
            color: labelColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelCenter = Offset(
        center.dx + math.cos(angle) * (radius + 22),
        center.dy + math.sin(angle) * (radius + 22),
      );
      label.paint(
        canvas,
        Offset(
          (labelCenter.dx - label.width / 2).clamp(
            8.0,
            size.width - label.width - 8,
          ),
          (labelCenter.dy - label.height / 2).clamp(
            8.0,
            size.height - label.height - 8,
          ),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StudentPerformanceRadarPainter oldDelegate) =>
      oldDelegate.accuracyPercentage != accuracyPercentage ||
      oldDelegate.retentionPercentage != retentionPercentage ||
      oldDelegate.improvementPercentage != improvementPercentage ||
      oldDelegate.consistencyPercentage != consistencyPercentage ||
      oldDelegate.focusPercentage != focusPercentage ||
      oldDelegate.weeklyAccuracyPercentage != weeklyAccuracyPercentage ||
      oldDelegate.weeklyRetentionPercentage != weeklyRetentionPercentage ||
      oldDelegate.weeklyImprovementPercentage != weeklyImprovementPercentage ||
      oldDelegate.weeklyConsistencyPercentage != weeklyConsistencyPercentage ||
      oldDelegate.weeklyFocusPercentage != weeklyFocusPercentage ||
      oldDelegate.showWeeklySeries != showWeeklySeries ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.weeklyColor != weeklyColor;
}
