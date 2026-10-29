import 'package:flutter/material.dart';

class ClassroomModel {
  const ClassroomModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.code,
    required this.createdAt,
    this.iconKey = 'book',
    this.studentCount = 0,
    this.activityCount = 0,
  });

  static const iconOptions = <ClassroomIconOption>[
    ClassroomIconOption(
      key: 'book',
      label: 'Book',
      icon: Icons.menu_book_outlined,
    ),
    ClassroomIconOption(
      key: 'science',
      label: 'Science',
      icon: Icons.science_outlined,
    ),
    ClassroomIconOption(
      key: 'computer',
      label: 'Technology',
      icon: Icons.computer_outlined,
    ),
    ClassroomIconOption(
      key: 'calculate',
      label: 'Math',
      icon: Icons.calculate_outlined,
    ),
    ClassroomIconOption(
      key: 'palette',
      label: 'Art',
      icon: Icons.palette_outlined,
    ),
    ClassroomIconOption(
      key: 'language',
      label: 'Language',
      icon: Icons.translate_outlined,
    ),
    ClassroomIconOption(
      key: 'history',
      label: 'History',
      icon: Icons.account_balance_outlined,
    ),
    ClassroomIconOption(
      key: 'music',
      label: 'Music',
      icon: Icons.music_note_outlined,
    ),
  ];

  final String id;
  final String name;
  final String subject;
  final String code;
  final DateTime createdAt;
  final String iconKey;
  final int studentCount;
  final int activityCount;

  IconData get icon => iconOptions
      .firstWhere(
        (option) => option.key == iconKey,
        orElse: () => iconOptions.first,
      )
      .icon;

  factory ClassroomModel.fromJson(Map<String, dynamic> json) => ClassroomModel(
    id: json['id'] as String,
    name: json['name'] as String,
    subject: json['subject'] as String,
    code: json['code'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    iconKey: json['icon_key'] as String? ?? 'book',
    studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
    activityCount: (json['activity_count'] as num?)?.toInt() ?? 0,
  );
}

class InstructorDashboardStats {
  const InstructorDashboardStats({
    required this.studentCount,
    required this.activeClassCount,
    this.quizzesCreatedCount = 0,
    this.classroomPerformance = const [],
  });

  final int studentCount;
  final int activeClassCount;
  final int quizzesCreatedCount;
  final List<ClassroomPerformance> classroomPerformance;

  factory InstructorDashboardStats.fromJson(Map<String, dynamic> json) =>
      InstructorDashboardStats(
        studentCount: (json['student_count'] as num).toInt(),
        activeClassCount: (json['active_class_count'] as num).toInt(),
        quizzesCreatedCount: (json['quizzes_created_count'] as num).toInt(),
        classroomPerformance: (json['classroom_performance'] as List<dynamic>)
            .map(
              (classroom) => ClassroomPerformance.fromJson(
                Map<String, dynamic>.from(classroom as Map),
              ),
            )
            .toList(growable: false),
      );
}

class ClassroomPerformance {
  const ClassroomPerformance({
    required this.name,
    required this.subject,
    required this.studentCount,
    required this.activityCount,
    required this.averageScore,
  });

  final String name;
  final String subject;
  final int studentCount;
  final int activityCount;
  final double? averageScore;

  factory ClassroomPerformance.fromJson(Map<String, dynamic> json) =>
      ClassroomPerformance(
        name: json['name'] as String,
        subject: json['subject'] as String,
        studentCount: (json['student_count'] as num).toInt(),
        activityCount: (json['activity_count'] as num).toInt(),
        averageScore: (json['average_score'] as num?)?.toDouble(),
      );
}

class ClassroomStudentSummary {
  const ClassroomStudentSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.joinedAt,
  });

  final int id;
  final String fullName;
  final String email;
  final DateTime joinedAt;

  factory ClassroomStudentSummary.fromJson(Map<String, dynamic> json) =>
      ClassroomStudentSummary(
        id: (json['id'] as num).toInt(),
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

class ClassroomIconOption {
  const ClassroomIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}
