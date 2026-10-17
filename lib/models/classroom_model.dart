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
  );
}

class InstructorDashboardStats {
  const InstructorDashboardStats({
    required this.studentCount,
    required this.activeClassCount,
  });

  final int studentCount;
  final int activeClassCount;

  factory InstructorDashboardStats.fromJson(Map<String, dynamic> json) =>
      InstructorDashboardStats(
        studentCount: (json['student_count'] as num).toInt(),
        activeClassCount: (json['active_class_count'] as num).toInt(),
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
