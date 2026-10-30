import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/learning_material_model.dart';
import 'package:thesis_repo_renew/screens/learning_materials_screen.dart';
import 'package:thesis_repo_renew/services/instructor_learning_materials_service.dart';

void main() {
  testWidgets('learning materials can be organized without classroom posting', (
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
          body: LearningMaterialsScreen(materialsRepository: materials),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning Materials'), findsOneWidget);
    expect(find.text('Cell Structure'), findsOneWidget);
    expect(find.text('biology.pdf'), findsOneWidget);
    expect(find.text('12 questions'), findsOneWidget);
    expect(find.text('Post to classroom'), findsNothing);
    expect(find.text('Posted in Biology'), findsNothing);
    expect(find.text('Folder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can confirm deletion from their library', (
    tester,
  ) async {
    final materials = _FakeMaterialsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMaterialsScreen(materialsRepository: materials),
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
          body: LearningMaterialsScreen(materialsRepository: materials),
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
}

class _FakeMaterialsRepository
    implements InstructorLearningMaterialsRepository {
  bool isDeleted = false;
  final List<String> deletedQuizIds = [];
  final List<LearningMaterialFolder> folders = [];
  String? assignedQuizId;
  String? assignedFolderId;

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
}
