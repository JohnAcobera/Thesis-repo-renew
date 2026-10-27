import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/models/learning_material_model.dart';
import 'package:thesis_repo_renew/screens/learning_materials_screen.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/instructor_learning_materials_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  testWidgets('learning materials can be posted to selected classrooms', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    final materials = _FakeMaterialsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMaterialsScreen(
            classroomService: _FakeClassroomRepository(),
            materialsRepository: materials,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning Materials'), findsOneWidget);
    expect(find.text('Cell Structure'), findsOneWidget);
    expect(find.text('biology.pdf'), findsOneWidget);
    expect(find.text('12 questions'), findsOneWidget);
    expect(find.text('Posted in Biology'), findsOneWidget);

    await tester.tap(find.text('Post to classroom'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Post to classrooms'), findsOneWidget);
    expect(find.text('Deadline'), findsNothing);
    await tester.tap(find.text('Post activity'));
    await tester.pumpAndSettle();

    expect(materials.postedQuizId, 'quiz-1');
    expect(materials.postedClassroomIds, ['class-1']);
    expect(
      find.text('Activity posted to the selected classrooms.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can confirm deletion from their library', (
    tester,
  ) async {
    final materials = _FakeMaterialsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMaterialsScreen(
            classroomService: _FakeClassroomRepository(),
            materialsRepository: materials,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete saved quiz?'), findsOneWidget);
    await tester.tap(find.text('Delete quiz'));
    await tester.pumpAndSettle();

    expect(materials.deletedQuizIds, ['quiz-1']);
    expect(find.text('Your library is ready'), findsOneWidget);
    expect(find.text('Quiz deleted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can create folders and move quizzes into them', (
    tester,
  ) async {
    final materials = _FakeMaterialsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMaterialsScreen(
            classroomService: _FakeClassroomRepository(),
            materialsRepository: materials,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Biology');
    await tester.tap(find.widgetWithText(FilledButton, 'Create folder'));
    await tester.pumpAndSettle();

    expect(materials.folders.single.name, 'Biology');
    expect(find.text('Folder “Biology” created'), findsOneWidget);
    await tester.tap(find.text('Unfiled').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biology').last);
    await tester.pumpAndSettle();

    expect(materials.assignedQuizId, 'quiz-1');
    expect(materials.assignedFolderId, 'folder-1');
    expect(find.text('Biology'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create activity shortcut invokes its navigation callback', (
    tester,
  ) async {
    var createActivityPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMaterialsScreen(
            classroomService: _FakeClassroomRepository(),
            materialsRepository: _FakeMaterialsRepository(),
            onCreateActivity: () => createActivityPressed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create activity'));
    expect(createActivityPressed, isTrue);
  });
}

class _FakeMaterialsRepository
    implements InstructorLearningMaterialsRepository {
  bool isDeleted = false;
  final List<String> deletedQuizIds = [];
  final List<LearningMaterialFolder> folders = [];
  String? assignedQuizId;
  String? assignedFolderId;
  String? postedQuizId;
  List<String> postedClassroomIds = [];

  @override
  Future<List<LearningMaterialModel>> listMaterials() async => isDeleted
      ? []
      : [
          LearningMaterialModel(
            id: 'quiz-1',
            title: 'Cell Structure',
            sourceFile: 'biology.pdf',
            createdAt: DateTime(2026, 10, 18),
            questionCount: 12,
            postedClassroomNames: const ['Biology'],
            folderId: assignedFolderId,
            folderName: folders
                .where((folder) => folder.id == assignedFolderId)
                .firstOrNull
                ?.name,
          ),
        ];

  @override
  Future<void> deleteMaterial(String quizId) async {
    deletedQuizIds.add(quizId);
    isDeleted = true;
  }

  @override
  Future<List<LearningMaterialFolder>> listFolders() async => folders;

  @override
  Future<LearningMaterialFolder> createFolder(String name) async {
    final folder = LearningMaterialFolder(
      id: 'folder-1',
      name: name,
      createdAt: DateTime(2026, 10, 19),
    );
    folders.add(folder);
    return folder;
  }

  @override
  Future<void> assignMaterialToFolder({
    required String quizId,
    required String? folderId,
  }) async {
    assignedQuizId = quizId;
    assignedFolderId = folderId;
  }

  @override
  Future<void> postMaterial({
    required String quizId,
    required List<String> classroomIds,
    required DateTime startsAt,
  }) async {
    postedQuizId = quizId;
    postedClassroomIds = classroomIds;
  }
}

class _FakeClassroomRepository implements ClassroomRepository {
  @override
  Future<List<ClassroomModel>> listClassrooms() async => [
    ClassroomModel(
      id: 'class-1',
      name: 'Biology',
      subject: 'General Biology',
      code: 'BIOLOGY1',
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<List<ClassroomStudentSummary>> classroomStudents(
    String classroomId,
  ) async => [];

  @override
  Future<void> removeClassroomStudent({
    required String classroomId,
    required int studentId,
  }) async {}

  @override
  Future<List<ClassroomActivity>> classroomActivities(
    String classroomId,
  ) async => [];

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      const InstructorDashboardStats(studentCount: 0, activeClassCount: 0);

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async => [];

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async =>
      throw UnimplementedError();

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteClassroom(String classroomId) async {}

  @override
  Future<void> deleteClassroomActivity({
    required String classroomId,
    required String activityId,
  }) async {}
}
