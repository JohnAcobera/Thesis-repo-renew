import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/instructor_todo_task.dart';
import 'auth_service.dart';

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

class TodoStorageException implements Exception {
  const TodoStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class TodoCloudStore {
  Future<String?> load(String sessionToken);

  Future<void> save(String sessionToken, String tasks);
}

class SupabaseTodoCloudStore implements TodoCloudStore {
  SupabaseTodoCloudStore({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<String?> load(String sessionToken) async {
    try {
      return await _supabase.rpc<String?>(
        'get_my_todos',
        params: {'p_session_token': sessionToken},
      );
    } on PostgrestException catch (error) {
      throw TodoStorageException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Task storage is not configured. Run '
                    'supabase/encrypted_todos.sql in the Supabase SQL Editor, '
                    'then reload the app.'
              : 'Your tasks could not be loaded from the database. Please try again.',
        ),
      );
    }
  }

  @override
  Future<void> save(String sessionToken, String tasks) async {
    try {
      await _supabase.rpc<void>(
        'save_my_todos',
        params: {'p_session_token': sessionToken, 'p_tasks': tasks},
      );
    } on PostgrestException catch (error) {
      throw TodoStorageException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Task storage is not configured. Run '
                    'supabase/encrypted_todos.sql in the Supabase SQL Editor, '
                    'then reload the app.'
              : 'Your tasks could not be saved to the database. Please try again.',
        ),
      );
    }
  }

  String _databaseMessage(
    PostgrestException error, {
    required String fallback,
  }) => error.message.contains('Invalid or expired session')
      ? 'Your session has expired. Please log in again.'
      : fallback;
}

abstract interface class LegacyTodoKeyStore {
  Future<String?> read(String key);
}

abstract interface class TodoSessionTokenProvider {
  Future<String?> getSessionToken();
}

class AuthTodoSessionTokenProvider implements TodoSessionTokenProvider {
  AuthTodoSessionTokenProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  @override
  Future<String?> getSessionToken() => _authService.getSessionToken();
}

class SecureLegacyTodoKeyStore implements LegacyTodoKeyStore {
  SecureLegacyTodoKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
}

class InstructorTodoService
    implements InstructorTodoRepository, TodoReminderReadRepository {
  InstructorTodoService({
    this.storageNamespace = 'instructor',
    SupabaseClient? client,
    AuthService? authService,
    TodoSessionTokenProvider? sessionTokenProvider,
    TodoCloudStore? cloudStore,
    LegacyTodoKeyStore? legacyKeyStore,
  }) : _client = client,
       _sessionTokenProvider =
           sessionTokenProvider ??
           AuthTodoSessionTokenProvider(authService: authService),
       _cloudStore = cloudStore,
       _legacyKeyStore = legacyKeyStore ?? SecureLegacyTodoKeyStore();

  final String storageNamespace;
  final SupabaseClient? _client;
  final TodoSessionTokenProvider _sessionTokenProvider;
  final TodoCloudStore? _cloudStore;
  final LegacyTodoKeyStore _legacyKeyStore;
  // Used only to migrate existing task lists encrypted by older app versions.
  static final _cipher = AesGcm.with256bits();

  String _storageKey(int instructorId) =>
      '${storageNamespace}_todos_$instructorId';

  String _legacyEncryptionKey(int ownerId) =>
      '$storageNamespace.todo.encryption_key.$ownerId';

  SupabaseTodoCloudStore get _database =>
      SupabaseTodoCloudStore(client: _client);

  TodoCloudStore get _cloud => _cloudStore ?? _database;

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
    final token = await _requireSessionToken();
    final cloudTasks = await _cloud.load(token);
    if (cloudTasks != null) {
      final decodedCloudTasks = _decodeCloudTasks(cloudTasks);
      if (decodedCloudTasks case final tasks?) return tasks;

      final secretKey = await _readLegacyKey(instructorId);
      if (secretKey == null) {
        await saveTasks(instructorId, const []);
        return const [];
      }
      final tasks = _decodeTasks(await _decrypt(cloudTasks, secretKey));
      await saveTasks(instructorId, tasks);
      return tasks;
    }

    final preferences = await SharedPreferences.getInstance();
    final legacyTasks = preferences.getString(_storageKey(instructorId));
    if (legacyTasks == null) return const [];
    final tasks = _decodeTasks(legacyTasks);
    await saveTasks(instructorId, tasks);
    final removed = await preferences.remove(_storageKey(instructorId));
    if (!removed) {
      throw const TodoStorageException(
        'Your tasks were saved to the database, but the unencrypted local '
        'copy could not be removed. Please try loading them again.',
      );
    }
    return tasks;
  }

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {
    final token = await _requireSessionToken();
    final tasksJson = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await _cloud.save(token, tasksJson);
  }

  Future<String> _requireSessionToken() async {
    final token = await _sessionTokenProvider.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const TodoStorageException(
        'Your session has expired. Please log in again.',
      );
    }
    return token;
  }

  Future<SecretKey?> _readLegacyKey(int ownerId) async {
    final encoded = await _legacyKeyStore.read(_legacyEncryptionKey(ownerId));
    if (encoded == null) return null;
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length != 32) {
        throw const FormatException('Invalid todo encryption key length.');
      }
      return SecretKey(bytes);
    } on FormatException {
      throw const TodoStorageException(
        'The secure key for your tasks is invalid. Your encrypted tasks '
        'cannot be read.',
      );
    }
  }

  List<InstructorTodoTask>? _decodeCloudTasks(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List<dynamic>) return _decodeTasks(value);
      if (decoded is Map<String, dynamic> && decoded['version'] == 1) {
        return null;
      }
    } on FormatException {
      throw const TodoStorageException(
        'Your saved tasks could not be read. Please try again.',
      );
    }
    throw const TodoStorageException(
      'Your saved tasks could not be read. Please try again.',
    );
  }

  Future<String> _decrypt(String encrypted, SecretKey key) async {
    try {
      final envelope = jsonDecode(encrypted) as Map<String, dynamic>;
      if (envelope['version'] != 1) {
        throw const FormatException('Unsupported encrypted todo version.');
      }
      final secretBox = SecretBox(
        base64Decode(envelope['ciphertext'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      );
      return utf8.decode(await _cipher.decrypt(secretBox, secretKey: key));
    } on SecretBoxAuthenticationError {
      throw const TodoStorageException(
        'Your encrypted tasks could not be verified or decrypted.',
      );
    } on FormatException {
      throw const TodoStorageException(
        'Your encrypted tasks could not be read. Please try again.',
      );
    } on ArgumentError {
      throw const TodoStorageException(
        'Your encrypted tasks could not be read. Please try again.',
      );
    } on TypeError {
      throw const TodoStorageException(
        'Your encrypted tasks could not be read. Please try again.',
      );
    }
  }

  List<InstructorTodoTask> _decodeTasks(String encoded) {
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .map(
            (item) => InstructorTodoTask.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const TodoStorageException(
        'Your saved tasks could not be read. Please try again.',
      );
    } on TypeError {
      throw const TodoStorageException(
        'Your saved tasks could not be read. Please try again.',
      );
    }
  }
}

class StudentTodoService extends InstructorTodoService {
  StudentTodoService({
    super.client,
    super.authService,
    super.sessionTokenProvider,
    super.cloudStore,
    super.legacyKeyStore,
  }) : super(storageNamespace: 'student');
}
