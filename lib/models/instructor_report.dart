class InstructorReportClassroom {
  const InstructorReportClassroom({
    required this.id,
    required this.name,
    required this.subject,
    required this.studentCount,
    required this.activityCount,
    required this.averageScore,
    required this.students,
  });

  final String id;
  final String name;
  final String subject;
  final int studentCount;
  final int activityCount;
  final double? averageScore;
  final List<InstructorReportStudent> students;

  factory InstructorReportClassroom.fromJson(Map<String, dynamic> json) =>
      InstructorReportClassroom(
        id: json['id'] as String,
        name: json['name'] as String,
        subject: json['subject'] as String,
        studentCount: (json['student_count'] as num).toInt(),
        activityCount: (json['activity_count'] as num).toInt(),
        averageScore: (json['average_score'] as num?)?.toDouble(),
        students: (json['students'] as List<dynamic>)
            .map(
              (student) => InstructorReportStudent.fromJson(
                Map<String, dynamic>.from(student as Map),
              ),
            )
            .toList(growable: false),
      );
}

class InstructorReportStudent {
  const InstructorReportStudent({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.createdAt,
    required this.completedActivityCount,
    required this.totalActivityCount,
    required this.attemptCount,
    required this.averageScore,
    required this.generatedQuizCount,
    required this.personalAttemptCount,
    required this.personalAverageScore,
    this.accuracyPercentage,
    this.retentionPercentage,
    this.improvementPercentage,
    this.consistencyPercentage,
    this.focusPercentage,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final DateTime joinedAt;
  final DateTime? createdAt;
  final int completedActivityCount;
  final int totalActivityCount;
  final int attemptCount;
  final double? averageScore;
  final int generatedQuizCount;
  final int personalAttemptCount;
  final double? personalAverageScore;
  final double? accuracyPercentage;
  final double? retentionPercentage;
  final double? improvementPercentage;
  final double? consistencyPercentage;
  final double? focusPercentage;

  factory InstructorReportStudent.fromJson(
    Map<String, dynamic> json,
  ) => InstructorReportStudent(
    id: (json['id'] as num).toInt(),
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    joinedAt: DateTime.parse(json['joined_at'] as String),
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
    completedActivityCount: (json['completed_activity_count'] as num).toInt(),
    totalActivityCount: (json['total_activity_count'] as num).toInt(),
    attemptCount: (json['attempt_count'] as num).toInt(),
    averageScore: (json['average_score'] as num?)?.toDouble(),
    generatedQuizCount: (json['generated_quiz_count'] as num).toInt(),
    personalAttemptCount: (json['personal_attempt_count'] as num).toInt(),
    personalAverageScore: (json['personal_average_score'] as num?)?.toDouble(),
    accuracyPercentage: (json['accuracy_percentage'] as num?)?.toDouble(),
    retentionPercentage: (json['retention_percentage'] as num?)?.toDouble(),
    improvementPercentage: (json['improvement_percentage'] as num?)?.toDouble(),
    consistencyPercentage: (json['consistency_percentage'] as num?)?.toDouble(),
    focusPercentage: (json['focus_percentage'] as num?)?.toDouble(),
  );
}
