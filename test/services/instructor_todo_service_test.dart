import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'instructor tasks are stored as plaintext and can be restored',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cloudStore = _FakeTodoCloudStore();
      final keyStore = _FakeLegacyTodoKeyStore();
      final service = _service(
        cloudStore: cloudStore,
        legacyKeyStore: keyStore,
        sessionToken: 'instructor-session',
      );
      final task = InstructorTodoTask(
        id: 'task-1',
        title: 'Review submissions',
        notes: 'Focus on chapter two',
        dueDate: DateTime(2026, 10, 21, 14, 30),
        priority: InstructorTodoPriority.high,
      );

      await service.saveTasks(12, [task]);

      final storedValue = cloudStore.values['instructor-session']!;
      expect(storedValue, contains('Review submissions'));
      expect(storedValue, contains('Focus on chapter two'));

      final restored = await _service(
        cloudStore: cloudStore,
        legacyKeyStore: keyStore,
        sessionToken: 'instructor-session',
      ).listTasks(12);
      expect(restored, hasLength(1));
      expect(restored.single.toJson(), task.toJson());
      expect(keyStore.values, isEmpty);
    },
  );

  test('student tasks are stored as plaintext', () async {
    SharedPreferences.setMockInitialValues({});
    final cloudStore = _FakeTodoCloudStore();
    final task = InstructorTodoTask(
      id: 'student-task',
      title: 'Practice spelling',
      dueDate: DateTime(2026, 10, 21),
      priority: InstructorTodoPriority.normal,
    );
    final service = StudentTodoService(
      cloudStore: cloudStore,
      sessionTokenProvider: _FakeTodoSessionTokenProvider('student-session'),
    );

    await service.saveTasks(23, [task]);

    expect(jsonDecode(cloudStore.values['student-session']!) as List<dynamic>, [
      task.toJson(),
    ]);
  });

  test('legacy encrypted tasks migrate to plaintext cloud storage', () async {
    SharedPreferences.setMockInitialValues({});
    final cloudStore = _FakeTodoCloudStore();
    final keyBytes = List<int>.generate(32, (index) => index);
    final task = InstructorTodoTask(
      id: 'legacy-task',
      title: 'Migrate this task',
      notes: 'Keep its notes',
      dueDate: DateTime(2026, 10, 21),
      priority: InstructorTodoPriority.high,
    );
    cloudStore.values['legacy-session'] = await _encryptLegacyTasks([
      task,
    ], keyBytes);
    final keyStore = _FakeLegacyTodoKeyStore()
      ..values['instructor.todo.encryption_key.12'] = base64Encode(keyBytes);

    final restored = await _service(
      cloudStore: cloudStore,
      legacyKeyStore: keyStore,
      sessionToken: 'legacy-session',
    ).listTasks(12);

    expect(restored.single.toJson(), task.toJson());
    expect(jsonDecode(cloudStore.values['legacy-session']!) as List<dynamic>, [
      task.toJson(),
    ]);
    expect(cloudStore.values['legacy-session'], contains('Migrate this task'));
  });

  test('plaintext cloud tasks are isolated by signed-in account', () async {
    SharedPreferences.setMockInitialValues({});
    final cloudStore = _FakeTodoCloudStore();
    final keyStore = _FakeLegacyTodoKeyStore();
    final task = InstructorTodoTask(
      id: 'task-1',
      title: 'Review a topic',
      dueDate: DateTime(2026, 10, 21),
      priority: InstructorTodoPriority.normal,
    );

    await _service(
      cloudStore: cloudStore,
      legacyKeyStore: keyStore,
      sessionToken: 'account-one',
    ).saveTasks(12, [task]);
    expect(
      await _service(
        cloudStore: cloudStore,
        legacyKeyStore: keyStore,
        sessionToken: 'account-two',
      ).listTasks(12),
      isEmpty,
    );

    expect(cloudStore.values.keys, contains('account-one'));
  });

  test('legacy local tasks migrate to plaintext cloud storage', () async {
    SharedPreferences.setMockInitialValues({
      'instructor_todos_12':
          '[{"id":"task-1","title":"Review submissions",'
          '"due_date":"2026-10-21","priority":"normal","notes":"",'
          '"is_completed":false}]',
    });
    final cloudStore = _FakeTodoCloudStore();
    final tasks = await _service(
      cloudStore: cloudStore,
      legacyKeyStore: _FakeLegacyTodoKeyStore(),
      sessionToken: 'migration-session',
    ).listTasks(12);

    expect(tasks.single.dueDate, DateTime(2026, 10, 21));
    expect(
      cloudStore.values['migration-session'],
      contains('Review submissions'),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('instructor_todos_12'), isFalse);
  });

  test(
    'legacy encrypted tasks without a key are cleared when selected',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cloudStore = _FakeTodoCloudStore()
        ..values['other-device'] = '{"version":1}';

      final tasks = await _service(
        cloudStore: cloudStore,
        legacyKeyStore: _FakeLegacyTodoKeyStore(),
        sessionToken: 'other-device',
      ).listTasks(12);

      expect(tasks, isEmpty);
      expect(
        jsonDecode(cloudStore.values['other-device']!) as List<dynamic>,
        isEmpty,
      );
    },
  );

  test(
    'reminders become overdue at timed deadline but date-only stays due today',
    () async {
      final now = DateTime(2026, 11, 16, 16, 27);
      final repository = _FakeTodoRepository([
        InstructorTodoTask(
          id: 'deadline-now',
          title: 'Send report',
          dueDate: now,
          priority: InstructorTodoPriority.high,
        ),
        InstructorTodoTask(
          id: 'deadline-later',
          title: 'Finish notes',
          dueDate: now.add(const Duration(minutes: 1)),
          priority: InstructorTodoPriority.normal,
        ),
        InstructorTodoTask(
          id: 'date-only',
          title: 'Review material',
          dueDate: DateTime(now.year, now.month, now.day),
          priority: InstructorTodoPriority.low,
        ),
        InstructorTodoTask(
          id: 'tomorrow',
          title: 'Prepare slides',
          dueDate: DateTime(now.year, now.month, now.day + 1, 15),
          priority: InstructorTodoPriority.normal,
        ),
      ]);

      final reminders = await listTodoReminders(repository, 12, now: now);
      final byTaskId = {
        for (final reminder in reminders) reminder.taskId: reminder,
      };

      expect(byTaskId['deadline-now']?.title, 'Task overdue');
      expect(
        byTaskId['deadline-now']?.message,
        '"Send report" was due 11/16 at 4:27 PM.',
      );
      expect(byTaskId['deadline-later']?.title, 'Task due today');
      expect(byTaskId['date-only']?.title, 'Task due today');
      expect(byTaskId['deadline-now']?.createdAt, now);
      expect(byTaskId['deadline-later']?.createdAt, now);
      expect(byTaskId['tomorrow']?.createdAt, now);
    },
  );

  test('upcoming reminder timestamp stays fixed across refreshes', () async {
    final first = DateTime(2026, 11, 27, 15);
    final later = first.add(const Duration(minutes: 10));
    final repository = _FakeTodoRepositoryWithReminderStore([
      InstructorTodoTask(
        id: 'tomorrow',
        title: 'Prepare slides',
        dueDate: DateTime(first.year, first.month, first.day + 1, 15),
        priority: InstructorTodoPriority.normal,
      ),
    ]);

    final initial = await listTodoReminders(repository, 12, now: first);
    final refreshed = await listTodoReminders(repository, 12, now: later);

    expect(initial.single.createdAt, first);
    expect(refreshed.single.createdAt, first);
  });

  test('overdue reminder timestamp is the deadline, not first-seen', () async {
    final seenAt = DateTime(2026, 11, 27, 15, 33);
    final deadline = DateTime(2026, 11, 27, 15, 32);
    final repository = _FakeTodoRepositoryWithReminderStore([
      InstructorTodoTask(
        id: 'overdue',
        title: 'Past due task',
        dueDate: deadline,
        priority: InstructorTodoPriority.normal,
      ),
    ]);

    final reminders = await listTodoReminders(repository, 12, now: seenAt);

    expect(reminders.single.title, 'Task overdue');
    expect(reminders.single.createdAt, deadline);
  });

  test('reminder refresh aligns with the next minute boundary', () {
    expect(
      durationUntilNextMinute(DateTime(2026, 11, 16, 16, 27, 0)),
      const Duration(minutes: 1),
    );
    expect(
      durationUntilNextMinute(DateTime(2026, 11, 16, 16, 27, 30)),
      const Duration(seconds: 30),
    );
  });
}

InstructorTodoService _service({
  required TodoCloudStore cloudStore,
  required LegacyTodoKeyStore legacyKeyStore,
  required String sessionToken,
}) => InstructorTodoService(
  cloudStore: cloudStore,
  legacyKeyStore: legacyKeyStore,
  sessionTokenProvider: _FakeTodoSessionTokenProvider(sessionToken),
);

class _FakeTodoCloudStore implements TodoCloudStore {
  final Map<String, String> values = {};

  @override
  Future<String?> load(String sessionToken) async => values[sessionToken];

  @override
  Future<void> save(String sessionToken, String tasks) async {
    values[sessionToken] = tasks;
  }
}

class _FakeLegacyTodoKeyStore implements LegacyTodoKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];
}

class _FakeTodoSessionTokenProvider implements TodoSessionTokenProvider {
  const _FakeTodoSessionTokenProvider(this.token);

  final String token;

  @override
  Future<String?> getSessionToken() async => token;
}

class _FakeTodoRepository implements InstructorTodoRepository {
  _FakeTodoRepository(this.tasks);

  final List<InstructorTodoTask> tasks;

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async => tasks;

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {}
}

class _FakeTodoRepositoryWithReminderStore
    implements InstructorTodoRepository, TodoReminderReadRepository {
  _FakeTodoRepositoryWithReminderStore(this.tasks);

  final List<InstructorTodoTask> tasks;
  final Map<String, DateTime> firstSeen = {};
  final Set<String> readIds = {};

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async => tasks;

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {}

  @override
  Future<bool> isReminderRead(int ownerId, String taskId) async =>
      readIds.contains(taskId);

  @override
  Future<void> markReminderRead(int ownerId, String taskId) async =>
      readIds.add(taskId);

  @override
  Future<DateTime?> reminderFirstSeen(int ownerId, String taskId) async =>
      firstSeen[taskId];

  @override
  Future<void> recordReminderSeen(
    int ownerId,
    String taskId,
    DateTime seenAt,
  ) async => firstSeen[taskId] = seenAt;
}

Future<String> _encryptLegacyTasks(
  List<InstructorTodoTask> tasks,
  List<int> keyBytes,
) async {
  final secretBox = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(tasks.map((task) => task.toJson()).toList())),
    secretKey: SecretKey(keyBytes),
  );
  return jsonEncode({
    'version': 1,
    'nonce': base64Encode(secretBox.nonce),
    'ciphertext': base64Encode(secretBox.cipherText),
    'mac': base64Encode(secretBox.mac.bytes),
  });
}
