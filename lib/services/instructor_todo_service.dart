import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/instructor_todo_task.dart';

abstract interface class InstructorTodoRepository {
  Future<List<InstructorTodoTask>> listTasks(int instructorId);

  Future<void> saveTasks(int instructorId, List<InstructorTodoTask> tasks);
}

class InstructorTodoService implements InstructorTodoRepository {
  const InstructorTodoService();

  String _storageKey(int instructorId) => 'instructor_todos_$instructorId';

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
      throw Exception('Instructor tasks could not be saved on this device.');
    }
  }
}
