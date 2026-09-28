import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../import_screen.dart';
import '../../widgets/student_nav_bar.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({required this.user, super.key});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    void openImportScreen() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ImportScreen(username: user.fullName, email: user.email),
        ),
      );
    }

    return Scaffold(
      appBar: StudentNavBar(
        username: user.fullName,
        email: user.email,
        onImportSelected: openImportScreen,
      ),
      body: LayoutBuilder(
        builder: (context, viewport) {
          final isWide = viewport.maxWidth >= 800;
          final dashboardHeight = (viewport.maxHeight - 48)
              .clamp(520.0, 720.0)
              .toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: isWide
                    ? SizedBox(
                        height: dashboardHeight,
                        child: _WideStudentDashboard(
                          user: user,
                          onImportSelected: openImportScreen,
                        ),
                      )
                    : _StackedStudentDashboard(
                        user: user,
                        onImportSelected: openImportScreen,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WideStudentDashboard extends StatelessWidget {
  const _WideStudentDashboard({
    required this.user,
    required this.onImportSelected,
  });

  final UserModel user;
  final VoidCallback onImportSelected;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        flex: 6,
        child: Column(
          children: [
            Expanded(
              child: _DashboardPanel(
                key: _DashboardPanel.greetingPanelKey,
                icon: null,
                title: 'Your Stats',
                description: '',
                titleSize: 30,
                centerContent: true,
                titleAtTop: true,
                content: const _StudentMetricsChart(),
              ),
            ),
            const SizedBox(height: 20),
            _DashboardPanel(
              key: _DashboardPanel.learningOverviewPanelKey,
              icon: Icons.auto_stories_outlined,
              title: 'Learning overview',
              description: 'Your learning progress will appear here.',
              actionLabel: 'Generate study material',
              onAction: onImportSelected,
              centerContent: true,
            ),
          ],
        ),
      ),
      const SizedBox(width: 20),
      const Expanded(
        flex: 4,
        child: _DashboardPanel(
          key: _DashboardPanel.recentActivityPanelKey,
          icon: Icons.history,
          title: 'Recent activity',
          description: 'Your recent learning activity will appear here.',
        ),
      ),
    ],
  );
}

class _StackedStudentDashboard extends StatelessWidget {
  const _StackedStudentDashboard({
    required this.user,
    required this.onImportSelected,
  });

  final UserModel user;
  final VoidCallback onImportSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DashboardPanel(
        key: _DashboardPanel.greetingPanelKey,
        icon: null,
        title: 'Your Stats',
        description: '',
        titleSize: 28,
        centerContent: true,
        titleAtTop: true,
        content: const _StudentMetricsChart(),
      ),
      const SizedBox(height: 16),
      _DashboardPanel(
        key: _DashboardPanel.learningOverviewPanelKey,
        icon: Icons.auto_stories_outlined,
        title: 'Learning overview',
        description: 'Your learning progress will appear here.',
        actionLabel: 'Generate study material',
        onAction: onImportSelected,
        centerContent: true,
      ),
      const SizedBox(height: 16),
      const _DashboardPanel(
        key: _DashboardPanel.recentActivityPanelKey,
        icon: Icons.history,
        title: 'Recent activity',
        description: 'Your recent learning activity will appear here.',
      ),
    ],
  );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    super.key,
    this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.centerContent = false,
    this.titleAtTop = false,
    this.content,
    this.titleSize = 22,
  });

  static const greetingPanelKey = ValueKey<String>('dashboard_panel_1');
  static const learningOverviewPanelKey = ValueKey<String>('dashboard_panel_2');
  static const recentActivityPanelKey = ValueKey<String>('dashboard_panel_3');

  final IconData? icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool centerContent;
  final bool titleAtTop;
  final Widget? content;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(hasAction || content != null ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8D7C2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: hasAction ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: centerContent && !titleAtTop
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: centerContent
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFFF4773C), size: 28),
            SizedBox(
              height: hasAction
                  ? 12
                  : content != null
                  ? 8
                  : 16,
            ),
          ],
          Text(
            title,
            textAlign: centerContent ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3B2419),
            ),
          ),
          if (description.isNotEmpty) ...[
            SizedBox(
              height: hasAction
                  ? 8
                  : content != null
                  ? 6
                  : 10,
            ),
            Text(
              description,
              textAlign: centerContent ? TextAlign.center : TextAlign.start,
            ),
          ],
          if (content != null) ...[const SizedBox(height: 4), content!],
          if (hasAction) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: centerContent
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth * 0.6,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(actionLabel!),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentMetricsChart extends StatelessWidget {
  const _StudentMetricsChart();

  static const _metrics = [
    'Accuracy',
    'Retention',
    'Improvement',
    'Consistency',
    'Efficiency',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final chartHeight =
          (constraints.maxWidth * 0.4).clamp(140.0, 175.0).toDouble() * 1.2;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _RadarChartPainter(
                metrics: _metrics,
                gridColor: const Color(0xFFE9E1D8),
                accentColor: const Color(0xFFF4773C),
                labelColor: const Color(0xFF725F53),
              ),
            ),
          ),
          const Text(
            'Your metrics will appear as you complete learning activities.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF8A7A70)),
          ),
        ],
      );
    },
  );
}

class _RadarChartPainter extends CustomPainter {
  const _RadarChartPainter({
    required this.metrics,
    required this.gridColor,
    required this.accentColor,
    required this.labelColor,
  });

  final List<String> metrics;
  final Color gridColor;
  final Color accentColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty || size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min((size.width - 112) / 2, (size.height - 48) / 2);
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

    final centerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 31, centerPaint);

    final emptyLabel = TextPainter(
      text: TextSpan(
        text: 'No scores yet',
        style: TextStyle(
          color: accentColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emptyLabel.paint(
      canvas,
      Offset(
        center.dx - emptyLabel.width / 2,
        center.dy - emptyLabel.height / 2,
      ),
    );

    for (var index = 0; index < metrics.length; index++) {
      final angle = angles[index];
      final label = TextPainter(
        text: TextSpan(
          text: metrics[index],
          style: TextStyle(
            color: labelColor,
            fontSize: 14.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelCenter = Offset(
        center.dx + math.cos(angle) * (radius + 20),
        center.dy + math.sin(angle) * (radius + 20),
      );
      label.paint(
        canvas,
        Offset(
          (labelCenter.dx - label.width / 2).clamp(
            0.0,
            size.width - label.width,
          ),
          (labelCenter.dy - label.height / 2).clamp(
            0.0,
            size.height - label.height,
          ),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.labelColor != labelColor;
}
