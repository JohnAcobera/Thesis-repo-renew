import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tasks are encrypted in cloud storage and can be restored', () async {
    SharedPreferences.setMockInitialValues({});
    final cloudStore = _FakeTodoCloudStore();
    final keyStore = _FakeTodoEncryptionKeyStore();
    final service = _service(
      cloudStore: cloudStore,
      keyStore: keyStore,
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

    final encryptedValue = cloudStore.values['instructor-session']!;
    expect(encryptedValue, isNot(contains('Review submissions')));
    expect(encryptedValue, isNot(contains('Focus on chapter two')));

    final restored = await _service(
      cloudStore: cloudStore,
      keyStore: keyStore,
      sessionToken: 'instructor-session',
    ).listTasks(12);
    expect(restored, hasLength(1));
    expect(restored.single.toJson(), task.toJson());
  });

  test('encrypted tasks are isolated by signed-in account', () async {
    SharedPreferences.setMockInitialValues({});
    final cloudStore = _FakeTodoCloudStore();
    final keyStore = _FakeTodoEncryptionKeyStore();
    final task = InstructorTodoTask(
      id: 'task-1',
      title: 'Review a topic',
      dueDate: DateTime(2026, 10, 21),
      priority: InstructorTodoPriority.normal,
    );

    await _service(
      cloudStore: cloudStore,
      keyStore: keyStore,
      sessionToken: 'account-one',
    ).saveTasks(12, [task]);
    expect(
      await _service(
        cloudStore: cloudStore,
        keyStore: keyStore,
        sessionToken: 'account-two',
      ).listTasks(12),
      isEmpty,
    );

    expect(cloudStore.values.keys, contains('account-one'));
  });

  test('legacy local tasks migrate to encrypted cloud storage', () async {
    SharedPreferences.setMockInitialValues({
      'instructor_todos_12':
          '[{"id":"task-1","title":"Review submissions",'
          '"due_date":"2026-10-21","priority":"normal","notes":"",'
          '"is_completed":false}]',
    });
    final cloudStore = _FakeTodoCloudStore();
    final keyStore = _FakeTodoEncryptionKeyStore();

    final tasks = await _service(
      cloudStore: cloudStore,
      keyStore: keyStore,
      sessionToken: 'migration-session',
    ).listTasks(12);

    expect(tasks.single.dueDate, DateTime(2026, 10, 21));
    expect(
      cloudStore.values['migration-session'],
      isNot(contains('Review submissions')),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('instructor_todos_12'), isFalse);
  });

  test('cloud tasks without a local secure key fail explicitly', () async {
    SharedPreferences.setMockInitialValues({});
    final cloudStore = _FakeTodoCloudStore()
      ..values['other-device'] = '{"version":1}';

    await expectLater(
      _service(
        cloudStore: cloudStore,
        keyStore: _FakeTodoEncryptionKeyStore(),
        sessionToken: 'other-device',
      ).listTasks(12),
      throwsA(isA<TodoStorageException>()),
    );
  });

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
    },
  );

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
  required TodoEncryptedCloudStore cloudStore,
  required TodoEncryptionKeyStore keyStore,
  required String sessionToken,
}) => InstructorTodoService(
  cloudStore: cloudStore,
  keyStore: keyStore,
  sessionTokenProvider: _FakeTodoSessionTokenProvider(sessionToken),
);

class _FakeTodoCloudStore implements TodoEncryptedCloudStore {
  final Map<String, String> values = {};

  @override
  Future<String?> load(String sessionToken) async => values[sessionToken];

  @override
  Future<void> save(String sessionToken, String encryptedTasks) async {
    values[sessionToken] = encryptedTasks;
  }
}

class _FakeTodoEncryptionKeyStore implements TodoEncryptionKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
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
