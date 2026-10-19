import 'dart:math' as math;

import 'package:flutter/material.dart';

class StudentPerformanceRadarChart extends StatelessWidget {
  const StudentPerformanceRadarChart({
    required this.accuracyPercentage,
    required this.retentionPercentage,
    required this.improvementPercentage,
    required this.consistencyPercentage,
    required this.focusPercentage,
    this.gridColor = const Color(0xFFE9E1D8),
    this.accentColor = const Color(0xFFF4773C),
    this.labelColor = const Color(0xFF725F53),
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

  static const _metrics = [
    'Accuracy',
    'Retention',
    'Improvement',
    'Consistency',
    'Focus',
  ];

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StudentPerformanceRadarPainter(
      accuracyPercentage: accuracyPercentage,
      retentionPercentage: retentionPercentage,
      improvementPercentage: improvementPercentage,
      consistencyPercentage: consistencyPercentage,
      focusPercentage: focusPercentage,
      gridColor: gridColor,
      accentColor: accentColor,
      labelColor: labelColor,
    ),
    child: const SizedBox.expand(),
  );
}

class _StudentPerformanceRadarPainter extends CustomPainter {
  const _StudentPerformanceRadarPainter({
    required this.accuracyPercentage,
    required this.retentionPercentage,
    required this.improvementPercentage,
    required this.consistencyPercentage,
    required this.focusPercentage,
    required this.gridColor,
    required this.accentColor,
    required this.labelColor,
  });

  final double? accuracyPercentage;
  final double? retentionPercentage;
  final double? improvementPercentage;
  final double? consistencyPercentage;
  final double? focusPercentage;
  final Color gridColor;
  final Color accentColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (StudentPerformanceRadarChart._metrics.isEmpty || size.isEmpty) return;

    final metrics = StudentPerformanceRadarChart._metrics;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min((size.width - 116) / 2, (size.height - 72) / 2);
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
    final metricPoints = List<Offset>.generate(metrics.length, (index) {
      final value = metricValues[index] ?? 0.0;
      final normalizedValue = value.clamp(0.0, 100.0) / 100;
      return Offset(
        center.dx + math.cos(angles[index]) * radius * normalizedValue,
        center.dy + math.sin(angles[index]) * radius * normalizedValue,
      );
    });

    if (metricValues.any((value) => value != null)) {
      final dataPath = Path()
        ..moveTo(metricPoints.first.dx, metricPoints.first.dy);
      for (final point in metricPoints.skip(1)) {
        dataPath.lineTo(point.dx, point.dy);
      }
      dataPath.close();
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = accentColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      for (var index = 0; index < metricPoints.length; index++) {
        if (metricValues[index] == null) continue;
        canvas.drawCircle(
          metricPoints[index],
          4,
          Paint()
            ..color = accentColor
            ..style = PaintingStyle.fill,
        );
      }
    }

    final centerLabel = TextPainter(
      text: TextSpan(
        text: accuracyPercentage == null
            ? 'No scores yet'
            : '${accuracyPercentage!.round()}%',
        style: TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerLabel.paint(
      canvas,
      Offset(
        center.dx - centerLabel.width / 2,
        center.dy - centerLabel.height / 2,
      ),
    );

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
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.labelColor != labelColor;
}
