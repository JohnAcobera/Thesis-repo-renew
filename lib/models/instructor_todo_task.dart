enum InstructorTodoPriority { high, normal, low }

class InstructorTodoTask {
  const InstructorTodoTask({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    this.notes = '',
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final InstructorTodoPriority priority;
  final String notes;
  final bool isCompleted;

  InstructorTodoTask copyWith({bool? isCompleted}) => InstructorTodoTask(
    id: id,
    title: title,
    dueDate: dueDate,
    priority: priority,
    notes: notes,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'due_date': _dateOnly(dueDate),
    'priority': priority.name,
    'notes': notes,
    'is_completed': isCompleted,
  };

  factory InstructorTodoTask.fromJson(Map<String, dynamic> json) {
    final priorityName = json['priority'] as String;
    final priority = InstructorTodoPriority.values.firstWhere(
      (value) => value.name == priorityName,
      orElse: () => throw FormatException(
        'Unknown instructor task priority: $priorityName',
      ),
    );
    return InstructorTodoTask(
      id: json['id'] as String,
      title: json['title'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      priority: priority,
      notes: json['notes'] as String,
      isCompleted: json['is_completed'] as bool,
    );
  }
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
