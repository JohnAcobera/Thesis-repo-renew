class AdminManagementData {
  const AdminManagementData({
    required this.teachers,
    required this.students,
    required this.classrooms,
    required this.activity,
  });

  final List<AdminManagedUser> teachers;
  final List<AdminManagedUser> students;
  final List<AdminManagedClassroom> classrooms;
  final List<AdminActivityEvent> activity;

  factory AdminManagementData.fromJson(Map<String, dynamic> json) =>
      AdminManagementData(
        teachers: _parseList(json['teachers'], AdminManagedUser.fromJson),
        students: _parseList(json['students'], AdminManagedUser.fromJson),
        classrooms: _parseList(
          json['classrooms'],
          AdminManagedClassroom.fromJson,
        ),
        activity: _parseList(json['activity'], AdminActivityEvent.fromJson),
      );
}

class AdminManagedUser {
  const AdminManagedUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.isActive,
    required this.classroomCount,
  });

  final int id;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final bool isActive;
  final int classroomCount;

  factory AdminManagedUser.fromJson(Map<String, dynamic> json) =>
      AdminManagedUser(
        id: (json['id'] as num).toInt(),
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isActive: json['is_active'] as bool,
        classroomCount: (json['classroom_count'] as num).toInt(),
      );
}

class AdminManagedClassroom {
  const AdminManagedClassroom({
    required this.id,
    required this.name,
    required this.subject,
    required this.code,
    required this.createdAt,
    required this.teacherName,
    required this.teacherEmail,
    required this.studentCount,
  });

  final String id;
  final String name;
  final String subject;
  final String code;
  final DateTime createdAt;
  final String teacherName;
  final String teacherEmail;
  final int studentCount;

  factory AdminManagedClassroom.fromJson(Map<String, dynamic> json) =>
      AdminManagedClassroom(
        id: json['id'] as String,
        name: json['name'] as String,
        subject: json['subject'] as String,
        code: json['code'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        teacherName: json['teacher_name'] as String,
        teacherEmail: json['teacher_email'] as String,
        studentCount: (json['student_count'] as num).toInt(),
      );
}

class AdminManagedClassroomStudent {
  const AdminManagedClassroomStudent({
    required this.id,
    required this.fullName,
    required this.email,
    required this.joinedAt,
  });

  final int id;
  final String fullName;
  final String email;
  final DateTime joinedAt;

  factory AdminManagedClassroomStudent.fromJson(Map<String, dynamic> json) =>
      AdminManagedClassroomStudent(
        id: (json['id'] as num).toInt(),
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

class AdminActivityEvent {
  const AdminActivityEvent({
    required this.id,
    required this.action,
    required this.targetLabel,
    required this.adminName,
    required this.createdAt,
  });

  final int id;
  final String action;
  final String targetLabel;
  final String adminName;
  final DateTime createdAt;

  factory AdminActivityEvent.fromJson(Map<String, dynamic> json) =>
      AdminActivityEvent(
        id: (json['id'] as num).toInt(),
        action: json['action'] as String,
        targetLabel: json['target_label'] as String,
        adminName: json['admin_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

List<T> _parseList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  return (value as List<dynamic>)
      .map((item) => parse(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);
}
