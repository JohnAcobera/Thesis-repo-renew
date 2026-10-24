class AdminOverview {
  const AdminOverview({
    required this.studentCount,
    required this.instructorCount,
    required this.classroomCount,
    required this.recentUpdates,
  });

  final int studentCount;
  final int instructorCount;
  final int classroomCount;
  final List<AdminRecentUpdate> recentUpdates;

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
    studentCount: (json['student_count'] as num).toInt(),
    instructorCount: (json['instructor_count'] as num).toInt(),
    classroomCount: (json['classroom_count'] as num).toInt(),
    recentUpdates: (json['recent_updates'] as List<dynamic>)
        .map(
          (update) => AdminRecentUpdate.fromJson(
            Map<String, dynamic>.from(update as Map),
          ),
        )
        .toList(growable: false),
  );
}

class AdminRecentUpdate {
  const AdminRecentUpdate({
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String type;
  final String title;
  final String description;
  final DateTime createdAt;

  factory AdminRecentUpdate.fromJson(Map<String, dynamic> json) =>
      AdminRecentUpdate(
        type: json['type'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
