import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/widgets/student_performance_radar_chart.dart';

void main() {
  testWidgets('shows a legend when comparing current and weekly stats', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 360,
          height: 240,
          child: StudentPerformanceRadarChart(
            accuracyPercentage: 70,
            retentionPercentage: 65,
            improvementPercentage: 10,
            consistencyPercentage: 50,
            focusPercentage: 60,
            showWeeklySeries: true,
            weeklyAccuracyPercentage: 75,
            weeklyRetentionPercentage: 70,
            weeklyImprovementPercentage: 20,
            weeklyConsistencyPercentage: 40,
            weeklyFocusPercentage: 80,
          ),
        ),
      ),
    );

    expect(find.text('Current stats'), findsOneWidget);
    expect(find.text('Past 7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
