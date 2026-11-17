import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/instructor_todo_task.dart';

abstract interface class InstructorTodoRepository {
  Future<List<InstructorTodoTask>> listTasks(int instructorId);

  Future<void> saveTasks(int instructorId, List<InstructorTodoTask> tasks);
}

abstract interface class TodoReminderReadRepository {
  Future<bool> isReminderRead(int ownerId, String taskId);

  Future<void> markReminderRead(int ownerId, String taskId);
}

class TodoReminder {
  const TodoReminder({
    required this.taskId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final String taskId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  String get id => 'todo-reminder:$taskId';
}

class TodoReminderException implements Exception {
  const TodoReminderException(this.message);

  final String message;

  @override
  String toString() => message;
}

Duration durationUntilNextMinute([DateTime? from]) {
  final now = from ?? DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute + 1,
  ).difference(now);
}

Future<List<TodoReminder>> listTodoReminders(
  InstructorTodoRepository repository,
  int ownerId, {
  DateTime? now,
}) async {
  final tasks = await repository.listTasks(ownerId);
  final TodoReminderReadRepository? readRepository =
      repository is TodoReminderReadRepository
      ? repository as TodoReminderReadRepository
      : null;
  final currentTime = now ?? DateTime.now();
  final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
  final tomorrow = today.add(const Duration(days: 1));
  final reminders = <TodoReminder>[];

  for (final task in tasks) {
    if (task.isCompleted) continue;
    final dueDate = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
    );
    if (dueDate.isAfter(tomorrow)) continue;

    final isDateOnly = task.dueDate.hour == 0 && task.dueDate.minute == 0;
    final deadline = isDateOnly
        ? dueDate.add(const Duration(days: 1))
        : task.dueDate;
    final isOverdue =
        dueDate.isBefore(today) || !currentTime.isBefore(deadline);
    final isDueTomorrow = dueDate == tomorrow;
    final title = isOverdue
        ? 'Task overdue'
        : isDueTomorrow
        ? 'Task due tomorrow'
        : 'Task due today';
    final message = isOverdue
        ? '"${task.title}" was due ${_formatReminderDeadline(task.dueDate, isDateOnly)}.'
        : isDueTomorrow
        ? '"${task.title}" is due tomorrow.'
        : '"${task.title}" is due today.';
    reminders.add(
      TodoReminder(
        taskId: task.id,
        title: title,
        message: message,
        createdAt: currentTime,
        isRead: await readRepository?.isReminderRead(ownerId, task.id) ?? false,
      ),
    );
  }
  return reminders;
}

String _formatReminderDeadline(DateTime dueDate, bool isDateOnly) {
  final date = '${dueDate.month}/${dueDate.day}';
  if (isDateOnly) return date;
  final hour = dueDate.hour % 12 == 0 ? 12 : dueDate.hour % 12;
  final minute = dueDate.minute.toString().padLeft(2, '0');
  final period = dueDate.hour < 12 ? 'AM' : 'PM';
  return '$date at $hour:$minute $period';
}

Future<void> markTodoRemindersRead(
  InstructorTodoRepository repository,
  int ownerId,
  List<String> taskIds,
) async {
  if (taskIds.isEmpty) return;
  if (repository is! TodoReminderReadRepository) {
    throw const TodoReminderException(
      'To-do reminders could not be marked as read.',
    );
  }
  final readRepository = repository as TodoReminderReadRepository;
  for (final taskId in taskIds) {
    await readRepository.markReminderRead(ownerId, taskId);
  }
}

class InstructorTodoService
    implements InstructorTodoRepository, TodoReminderReadRepository {
  const InstructorTodoService({this.storageNamespace = 'instructor'});

  final String storageNamespace;

  String _storageKey(int instructorId) =>
      '${storageNamespace}_todos_$instructorId';

  String _reminderReadKey(int ownerId, String taskId) =>
      '${storageNamespace}_todo_reminder_read_${ownerId}_$taskId';

  @override
  Future<bool> isReminderRead(int ownerId, String taskId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_reminderReadKey(ownerId, taskId)) ?? false;
  }

  @override
  Future<void> markReminderRead(int ownerId, String taskId) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(
      _reminderReadKey(ownerId, taskId),
      true,
    );
    if (!saved) {
      throw const TodoReminderException(
        'To-do reminders could not be marked as read on this device.',
      );
    }
  }

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async {
    final preferences = await SharedPreferences.getInstance();
    final encodedTasks = preferences.getString(_storageKey(instructorId));
    if (encodedTasks == null) return const [];
    final decoded = jsonDecode(encodedTasks) as List<dynamic>;
    return decoded
        .map(
          (item) => InstructorTodoTask.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey(instructorId),
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
    if (!saved) {
      final owner = storageNamespace == 'student' ? 'Student' : 'Instructor';
      throw Exception('$owner tasks could not be saved on this device.');
    }
  }
}

class StudentTodoService extends InstructorTodoService {
  const StudentTodoService() : super(storageNamespace: 'student');
}
