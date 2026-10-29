import 'dart:math' as math;

import 'package:flutter/material.dart';

class InstructorSummaryMetrics extends StatelessWidget {
  const InstructorSummaryMetrics({
    required this.classroomCount,
    required this.studentCount,
    this.studentsUnavailable = false,
    this.onRetryStudents,
    super.key,
  });

  final int? classroomCount;
  final int? studentCount;
  final bool studentsUnavailable;
  final VoidCallback? onRetryStudents;

  static const _accent = Color(0xFFF4773C);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);
  static const _border = Color(0xFFE8D7C2);
  static const _cardHeight = 88.0;
  static const _compactCardHeight = 152.0;
  static const _maxWidth = 1160.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, _maxWidth);
      final isCompact = width < 520;

      return Center(
        child: SizedBox(
          width: width,
          child: Container(
            key: const ValueKey('instructor-summary-metrics-card'),
            height: isCompact ? _compactCardHeight : _cardHeight,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 18,
              vertical: isCompact ? 10 : 0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isCompact
                ? Column(
                    children: [
                      Expanded(
                        child: _MetricContent(
                          key: const ValueKey('instructor-classrooms-metric'),
                          label: 'Classrooms',
                          value: classroomCount?.toString(),
                          icon: Icons.class_outlined,
                        ),
                      ),
                      const Divider(height: 1, color: _border),
                      Expanded(
                        child: _MetricContent(
                          key: const ValueKey('instructor-students-metric'),
                          label: 'Total students',
                          value: studentCount?.toString(),
                          icon: Icons.people_outline,
                          isUnavailable: studentsUnavailable,
                          onRetry: onRetryStudents,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _MetricContent(
                          key: const ValueKey('instructor-classrooms-metric'),
                          label: 'Classrooms',
                          value: classroomCount?.toString(),
                          icon: Icons.class_outlined,
                        ),
                      ),
                      const SizedBox(
                        height: 48,
                        child: VerticalDivider(width: 1, color: _border),
                      ),
                      Expanded(
                        child: _MetricContent(
                          key: const ValueKey('instructor-students-metric'),
                          label: 'Total students',
                          value: studentCount?.toString(),
                          icon: Icons.people_outline,
                          isUnavailable: studentsUnavailable,
                          onRetry: onRetryStudents,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

class _MetricContent extends StatelessWidget {
  const _MetricContent({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isUnavailable = false,
    this.onRetry,
  });

  final String label;
  final String? value;
  final IconData icon;
  final bool isUnavailable;
  final VoidCallback? onRetry;

  Widget _buildValue() {
    if (isUnavailable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '—',
            style: TextStyle(
              color: InstructorSummaryMetrics._ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Retry loading total students',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            ),
        ],
      );
    }
    return Text(
      value ?? '—',
      style: const TextStyle(
        color: InstructorSummaryMetrics._ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9DA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: InstructorSummaryMetrics._accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 26,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildValue(),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: InstructorSummaryMetrics._muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
