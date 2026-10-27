import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/home/student_home_screen.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';
import 'package:thesis_repo_renew/services/learning_mode_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  testWidgets('dashboard suggests the lowest recent quiz result', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final quizRepository = _FakeQuizRepository([
      _quizActivity(
        title: 'Recent topic',
        score: 40,
        attemptedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      _quizActivity(
        title: 'Older topic',
        score: 90,
        attemptedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
          quizRepository: quizRepository,
          learningModeService: _FakeLearningModeService(client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What should I review?'), findsOneWidget);
    expect(find.text('Recent topic'), findsNWidgets(2));
    expect(find.text('Your latest result was 40%.'), findsOneWidget);
    expect(find.text('Practice quiz'), findsOneWidget);

    await tester.tap(find.text('Practice quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Take your quiz'), findsOneWidget);
    expect(find.text('Recent topic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard suggests the least recently practiced activity', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final quizRepository = _FakeQuizRepository([
      _quizActivity(
        title: 'Recently practiced topic',
        score: 90,
        attemptedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      _quizActivity(
        title: 'Needs a refresh',
        score: 80,
        attemptedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
          quizRepository: quizRepository,
          learningModeService: _FakeLearningModeService(client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs a refresh'), findsNWidgets(2));
    expect(find.textContaining('You last practiced this on'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard opens the suggested flashcard activity', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final attemptedAt = DateTime.now().subtract(const Duration(days: 3));
    final item = LearningInventoryItem(
      id: 'flashcard-id',
      type: LearningActivityType.flashcards,
      title: 'Cell biology cards',
      sourceFile: 'biology.pdf',
      createdAt: attemptedAt,
      flashcards: const [
        Flashcard(
          question: 'What stores genetic information?',
          answer: 'The nucleus.',
          explanation: 'The nucleus contains DNA.',
        ),
      ],
      matchingPairs: const [],
      attempts: [
        LearningInventoryAttempt(
          score: 3,
          totalItems: 10,
          createdAt: attemptedAt,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
          quizRepository: const _FakeQuizRepository([]),
          learningModeService: _FakeLearningModeService(client, items: [item]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cell biology cards'), findsNWidgets(2));
    expect(find.text('Your latest result was 30%.'), findsOneWidget);
    await tester.tap(find.text('Review flashcards'));
    await tester.pumpAndSettle();
    expect(find.text('Study flashcards'), findsOneWidget);
    expect(find.text('What stores genetic information?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent flashcard activity opens a study attempt', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final attemptedAt = DateTime.now().subtract(const Duration(days: 3));
    final item = LearningInventoryItem(
      id: 'flashcard-id',
      type: LearningActivityType.flashcards,
      title: 'Cell biology cards',
      sourceFile: 'biology.pdf',
      createdAt: attemptedAt,
      flashcards: const [
        Flashcard(
          question: 'What stores genetic information?',
          answer: 'The nucleus.',
          explanation: 'The nucleus contains DNA.',
        ),
      ],
      matchingPairs: const [],
      attempts: [
        LearningInventoryAttempt(
          score: 3,
          totalItems: 10,
          createdAt: attemptedAt,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
          quizRepository: const _FakeQuizRepository([]),
          learningModeService: _FakeLearningModeService(client, items: [item]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activityTitle = find.text('Cell biology cards').last;
    await tester.ensureVisible(activityTitle);
    await tester.tap(activityTitle);
    await tester.pumpAndSettle();

    expect(find.text('Study flashcards'), findsOneWidget);
    expect(find.text('What stores genetic information?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent matching activity opens a study attempt', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final attemptedAt = DateTime.now().subtract(const Duration(days: 3));
    final item = LearningInventoryItem(
      id: 'matching-id',
      type: LearningActivityType.matching,
      title: 'Cell biology matching',
      sourceFile: 'biology.pdf',
      createdAt: attemptedAt,
      flashcards: const [],
      matchingPairs: const [
        MatchingPair(
          left: 'Nucleus',
          right: 'Stores genetic information',
          explanation: 'The nucleus contains DNA.',
        ),
      ],
      attempts: [
        LearningInventoryAttempt(
          score: 3,
          totalItems: 10,
          createdAt: attemptedAt,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
          quizRepository: const _FakeQuizRepository([]),
          learningModeService: _FakeLearningModeService(client, items: [item]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activityTitle = find.text('Cell biology matching').last;
    await tester.ensureVisible(activityTitle);
    await tester.tap(activityTitle);
    await tester.pumpAndSettle();

    expect(find.text('Match the concepts'), findsOneWidget);
    expect(find.text('Nucleus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard omits the practice section on mobile', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Come back and practice'), findsNothing);
    expect(find.text('Pending activities'), findsNothing);
    expect(find.text('Classroom deadlines'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent activity has a bounded scroll area on mobile', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recentActivityPanel = find.byKey(
      const ValueKey<String>('dashboard_panel_3'),
    );
    expect(tester.getSize(recentActivityPanel).height, 500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide dashboard fits the stats panel in a short viewport', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 700);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard omits generated quiz practice section', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Come back and practice'), findsNothing);
    expect(find.text('Practice quiz'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak calendar and todo list appear on dashboard', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    final todoRepository = _FakeTodoRepository([
      InstructorTodoTask(
        id: 'review',
        title: 'Review a topic',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        priority: InstructorTodoPriority.normal,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: todoRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your learning streak'), findsOneWidget);
    expect(find.text('2 days in a row'), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-calendar-grid')), findsOneWidget);
    final lastDayOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).day;
    expect(
      find.byKey(ValueKey<String>('streak-day-$lastDayOfMonth')),
      findsOneWidget,
    );
    final localizations = MaterialLocalizations.of(
      tester.element(find.text('Your learning streak')),
    );
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        localizations.formatMonthYear(
          DateTime(DateTime.now().year, DateTime.now().month - 1),
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        localizations.formatMonthYear(
          DateTime(DateTime.now().year, DateTime.now().month),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Learning day'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Review a topic'), findsOneWidget);
    expect(find.text('Come back and practice'), findsNothing);
    expect(find.text('Classroom deadlines'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _student = UserModel(
  id: 1,
  fullName: 'Student Name',
  email: 'student@example.com',
  role: 'student',
);

class _FakeProfileDataService implements ProfileDataService {
  @override
  Future<Set<DateTime>> loginDates() async {
    final today = DateTime.now();
    return {
      DateTime(today.year, today.month, today.day),
      DateTime(today.year, today.month, today.day - 1),
    };
  }

  @override
  Future<int> learnerPoints() async => 0;

  @override
  Future<int?> weeklyRanking() async => null;
}

class _FakeTodoRepository implements InstructorTodoRepository {
  _FakeTodoRepository([this.tasks = const []]);

  List<InstructorTodoTask> tasks;

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async =>
      List.unmodifiable(tasks);

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> updatedTasks,
  ) async {
    tasks = List.unmodifiable(updatedTasks);
  }
}

QuizActivity _quizActivity({
  required String title,
  required int score,
  required DateTime attemptedAt,
}) => QuizActivity(
  id: title,
  title: title,
  sourceFile: '$title.txt',
  createdAt: attemptedAt,
  questions: const [
    QuizQuestion(
      question: 'Does practice help learning?',
      options: ['True', 'False'],
      answerIndex: 0,
      explanation: 'Retrieval practice supports learning.',
    ),
  ],
  attempts: [
    QuizScore(score: score, totalQuestions: 100, createdAt: attemptedAt),
  ],
);

class _FakeQuizRepository implements QuizRepository {
  const _FakeQuizRepository(this.activities);

  final List<QuizActivity> activities;

  @override
  Future<List<QuizActivity>> recentAttempts() async => activities;
}

class _FakeLearningModeService extends LearningModeService {
  _FakeLearningModeService(SupabaseClient client, {this.items = const []})
    : super(
        client: client,
        authService: AuthService(client: client),
      );

  final List<LearningInventoryItem> items;

  @override
  Future<List<LearningInventoryItem>> inventoryItems() async => items;
}
