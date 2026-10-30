import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_screen.dart';
import 'quiz_screen.dart';
import 'study_activity_screens.dart';
import '../services/learning_mode_service.dart';
import '../services/quiz_service.dart';
import '../services/student_notification_service.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/student_side_menu.dart';

const _primary = Color(0xFFFF7434);
const _inputFill = Color(0xFFFFF1DF);
const _border = Color(0xFFE8D7C2);
const _heading = Color(0xFF3B2419);
const _subtle = Color(0xFF725F53);

class ImportScreen extends StatefulWidget {
  const ImportScreen({
    required this.username,
    required this.email,
    this.role = 'student',
    this.createdAt,
    this.onMenuSelected,
    this.notificationRepository,
    this.showTutorialOnOpen = false,
    super.key,
  });

  final String username;
  final String email;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;
  final StudentNotificationRepository? notificationRepository;
  final bool showTutorialOnOpen;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  PlatformFile? _selectedFile;
  final TextEditingController _quizNameController = TextEditingController();
  _LearningMode _selectedMode = _LearningMode.quiz;
  final Set<QuizQuestionType> _selectedTypes = {
    QuizQuestionType.multipleChoice,
  };
  int _selectedItemCount = 10;
  bool _isGenerating = false;
  bool _isDragHovered = false;
  bool _isTutorialVisible = false;
  bool _isTutorialPreferenceLoaded = false;
  int _tutorialStepIndex = 0;
  final ScrollController _setupScrollController = ScrollController();
  final Map<_TutorialStep, GlobalKey> _tutorialTargetKeys = {
    for (final step in _TutorialStep.values) step: GlobalKey(),
  };
  String? _generationStatus;
  DropzoneViewController? _dropzoneController;

  bool get _isInstructor => widget.role.toLowerCase() == 'instructor';

  String get _activityName => switch (_selectedMode) {
    _LearningMode.quiz => 'quiz',
    _LearningMode.flashcards => 'flashcard set',
    _LearningMode.matching => 'matching activity',
  };

  String get _tutorialPreferenceKey =>
      'quizforge_tutorial_dismissed_${widget.email.trim().toLowerCase()}';

  List<_TutorialStep> get _tutorialSteps => [
    _TutorialStep.start,
    _TutorialStep.learningMode,
    _TutorialStep.sourceFile,
    if (_selectedMode == _LearningMode.quiz) _TutorialStep.questionType,
    _TutorialStep.itemCount,
    _TutorialStep.generate,
  ];

  @override
  void initState() {
    super.initState();
    _isTutorialVisible = widget.showTutorialOnOpen;
    _loadTutorialPreference();
  }

  Future<void> _loadTutorialPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final dismissed = preferences.getBool(_tutorialPreferenceKey) ?? false;
      setState(() {
        _isTutorialVisible = !dismissed;
        _isTutorialPreferenceLoaded = true;
      });
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'quiz tutorial',
          context: ErrorDescription('while loading tutorial preferences'),
        ),
      );
      if (mounted) {
        setState(() {
          _isTutorialVisible = true;
          _isTutorialPreferenceLoaded = true;
        });
      }
    }
  }

  Future<void> _dismissTutorial() async {
    setState(() => _isTutorialVisible = false);
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setBool(_tutorialPreferenceKey, true);
      if (!saved && mounted) {
        _showMessage('Your tutorial preference could not be saved.');
      }
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'quiz tutorial',
          context: ErrorDescription('while saving tutorial preferences'),
        ),
      );
      if (mounted) {
        _showMessage('Your tutorial preference could not be saved.');
      }
    }
  }

  void _advanceTutorial(int direction) {
    final lastIndex = _tutorialSteps.length - 1;
    final nextIndex = (_tutorialStepIndex + direction)
        .clamp(0, lastIndex)
        .toInt();
    setState(() => _tutorialStepIndex = nextIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = _tutorialSteps[nextIndex];
      final targetContext = _tutorialTargetKeys[step]?.currentContext;
      if (targetContext == null) {
        if (step == _TutorialStep.start && _setupScrollController.hasClients) {
          _setupScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
          );
        }
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.12,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  String _displayRole(String role) => role.isEmpty
      ? role
      : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';

  Future<void> _pickFile() async {
    try {
      if (!mounted) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
        withData: true,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        _acceptFile(result.files.first);
      }
    } on Exception catch (e) {
      if (mounted) {
        _showMessage('Failed to pick file: $e', isError: true);
      }
    }
  }

  void _acceptFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    if (!const {'pdf', 'docx', 'txt'}.contains(extension)) {
      _showMessage('Choose a PDF, DOCX, or TXT file.', isError: true);
      return;
    }
    if (file.size > 3 * 1024 * 1024) {
      _showMessage('Choose a file that is 3 MB or smaller.', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _quizNameController.clear();
      _isDragHovered = false;
    });
  }

  Future<void> _handleWebDroppedFile(DropzoneFileInterface file) async {
    final controller = _dropzoneController;
    if (controller == null) {
      _showMessage('The drop area is still loading. Please try again.');
      return;
    }

    try {
      final name = await controller.getFilename(file);
      final size = await controller.getFileSize(file);
      if (!mounted) return;
      final extension = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : null;
      if (!const {'pdf', 'docx', 'txt'}.contains(extension)) {
        _showMessage('Choose a PDF, DOCX, or TXT file.', isError: true);
        return;
      }
      if (size > 3 * 1024 * 1024) {
        _showMessage('Choose a file that is 3 MB or smaller.', isError: true);
        return;
      }

      final bytes = await controller.getFileData(file);
      if (!mounted) return;
      _acceptFile(PlatformFile(name: name, size: size, bytes: bytes));
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(
          'The dropped file could not be read: $error',
          isError: true,
        );
      }
    } finally {
      _setDragHovered(false);
    }
  }

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    if (details.files.length > 1) {
      _showMessage('Drop one file at a time.', isError: true);
      return;
    }
    final file = details.files.first;
    if (file is DropItemDirectory) {
      _showMessage('Choose a file, not a folder.', isError: true);
      return;
    }

    try {
      final name = file.name;
      final size = await file.length();
      if (!mounted) return;
      final extension = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : null;
      if (!const {'pdf', 'docx', 'txt'}.contains(extension)) {
        _showMessage('Choose a PDF, DOCX, or TXT file.', isError: true);
        return;
      }
      if (size > 3 * 1024 * 1024) {
        _showMessage('Choose a file that is 3 MB or smaller.', isError: true);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      _acceptFile(PlatformFile(name: name, size: size, bytes: bytes));
    } on Exception {
      if (mounted) {
        _showMessage(
          'The dropped file could not be read. Please try browsing for it.',
          isError: true,
        );
      }
    } finally {
      _setDragHovered(false);
    }
  }

  void _setDragHovered(bool hovered) {
    if (!mounted || _isDragHovered == hovered) return;
    setState(() => _isDragHovered = hovered);
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _quizNameController.clear();
    });
  }

  Future<void> _generate() async {
    if (_selectedFile == null) return;
    final quizName = _quizNameController.text.trim();
    final selectedMode = _selectedMode;
    final selectedTypes = Set<QuizQuestionType>.of(_selectedTypes);
    final selectedItemCount = _selectedItemCount;
    if (quizName.isEmpty) {
      _showMessage('Enter a name for your $_activityName.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationStatus = 'Preparing your source material...';
    });

    try {
      final file = _selectedFile!;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const QuizServiceException(
          'The selected file could not be read. Please select it again.',
        );
      }

      final extension = file.extension?.toLowerCase();
      String? sourceText;
      if (extension == 'txt') {
        sourceText = utf8.decode(bytes, allowMalformed: true).trim();
      } else if (extension == 'pdf' || extension == 'docx') {
        setState(() => _generationStatus = 'Extracting text from your file...');
        sourceText = await QuizService().extractSourceText(
          fileName: file.name,
          fileBase64: base64Encode(bytes),
          mimeType: extension == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      } else {
        throw const QuizServiceException(
          'Use a PDF, DOCX, or TXT file to generate a quiz.',
        );
      }

      if (!mounted) return;
      if (sourceText.trim().isEmpty) {
        throw const QuizServiceException(
          'No readable text was found in the selected file.',
        );
      }
      if (sourceText.length > 100000) {
        throw const QuizServiceException(
          'The extracted text is too long. Choose a shorter file.',
        );
      }

      if (!mounted) return;
      setState(
        () => _generationStatus =
            'Generating $selectedItemCount ${selectedMode == _LearningMode.quiz ? 'questions' : 'items'}. This may take up to a minute...',
      );
      if (selectedMode == _LearningMode.quiz) {
        final questions = await QuizService().generateQuiz(
          questionCount: selectedItemCount,
          fileName: file.name,
          sourceText: sourceText,
          questionTypes: selectedTypes,
        );
        if (!mounted) return;
        setState(() => _isGenerating = false);

        if (_isInstructor) {
          await _showInstructorQuizActions(
            title: quizName,
            sourceFile: file.name,
            questions: questions,
          );
        } else {
          await _takeQuiz(
            title: quizName,
            sourceFile: file.name,
            questions: questions,
          );
        }
      } else if (selectedMode == _LearningMode.flashcards) {
        final service = LearningModeService();
        final cards = await service.generateFlashcards(
          itemCount: selectedItemCount,
          fileName: file.name,
          sourceText: sourceText,
        );
        final activityId = await service.saveActivity(
          type: LearningActivityType.flashcards,
          title: quizName,
          sourceFile: file.name,
          content: cards.map((card) => card.toJson()).toList(),
        );
        if (!mounted) return;
        setState(() => _isGenerating = false);
        await _takeFlashcards(
          activityId: activityId,
          title: quizName,
          sourceFile: file.name,
          cards: cards,
        );
      } else {
        final service = LearningModeService();
        final pairs = await service.generateMatchingPairs(
          itemCount: selectedItemCount,
          fileName: file.name,
          sourceText: sourceText,
        );
        final activityId = await service.saveActivity(
          type: LearningActivityType.matching,
          title: quizName,
          sourceFile: file.name,
          content: pairs.map((pair) => pair.toJson()).toList(),
        );
        if (!mounted) return;
        setState(() => _isGenerating = false);
        await _takeMatching(
          activityId: activityId,
          title: quizName,
          sourceFile: file.name,
          pairs: pairs,
        );
      }
    } on LearningModeServiceException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on QuizServiceException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on Exception {
      if (mounted) {
        _showMessage(
          'Learning activity generation failed. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted && _isGenerating) {
        setState(() {
          _isGenerating = false;
          _generationStatus = null;
        });
      }
    }
  }

  Future<void> _takeQuiz({
    required String title,
    required String sourceFile,
    required List<QuizQuestion> questions,
  }) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuizScreen(
          username: widget.username,
          email: widget.email,
          role: widget.role,
          createdAt: widget.createdAt,
          onMenuSelected: widget.onMenuSelected,
          notificationRepository: widget.notificationRepository,
          title: title,
          sourceFile: sourceFile,
          questions: questions,
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _takeFlashcards({
    required String activityId,
    required String title,
    required String sourceFile,
    required List<Flashcard> cards,
  }) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FlashcardsScreen(
          activityId: activityId,
          username: widget.username,
          email: widget.email,
          role: widget.role,
          title: title,
          sourceFile: sourceFile,
          cards: cards,
          createdAt: widget.createdAt,
          onMenuSelected: widget.onMenuSelected,
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _takeMatching({
    required String activityId,
    required String title,
    required String sourceFile,
    required List<MatchingPair> pairs,
  }) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MatchingScreen(
          activityId: activityId,
          username: widget.username,
          email: widget.email,
          role: widget.role,
          title: title,
          sourceFile: sourceFile,
          pairs: pairs,
          createdAt: widget.createdAt,
          onMenuSelected: widget.onMenuSelected,
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _showInstructorQuizActions({
    required String title,
    required String sourceFile,
    required List<QuizQuestion> questions,
  }) async {
    final action = await showDialog<_InstructorQuizAction>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFF8EE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _inputFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your quiz is ready',
                  style: TextStyle(
                    color: _heading,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you would like to use this quiz.',
                  style: TextStyle(color: _subtle, height: 1.45),
                ),
                const SizedBox(height: 20),
                _InstructorQuizChoice(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Take quiz',
                  description: 'Preview it and try the questions yourself.',
                  onTap: () =>
                      Navigator.pop(context, _InstructorQuizAction.take),
                ),
                const SizedBox(height: 10),
                _InstructorQuizChoice(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Save to library',
                  description: 'Keep it for later without sharing it yet.',
                  onTap: () =>
                      Navigator.pop(context, _InstructorQuizAction.save),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Not now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == _InstructorQuizAction.take) {
      await _takeQuiz(
        title: title,
        sourceFile: sourceFile,
        questions: questions,
      );
      return;
    }

    try {
      await QuizService().saveDraft(
        title: title,
        sourceFile: sourceFile,
        questions: questions,
      );
      if (!mounted) return;
      _showMessage('Quiz saved successfully.');
      Navigator.of(context).pop(true);
    } on QuizServiceException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on Exception {
      if (mounted) {
        _showMessage(
          'The quiz could not be saved. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _quizNameController.dispose();
    _setupScrollController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFA33A2B) : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: 'Create a Study Activity',
      username: widget.username,
      email: widget.email,
      role: _displayRole(widget.role),
      notificationRepository: widget.notificationRepository,
      onMenuSelected: (item) {
        if (item == StudentMenuItem.dashboard) {
          Navigator.of(context).pop();
        } else if (item == StudentMenuItem.profile) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(
                username: widget.username,
                email: widget.email,
                role: widget.role,
                createdAt: widget.createdAt,
                onMenuSelected: widget.onMenuSelected,
              ),
            ),
          );
        } else if (item == StudentMenuItem.classroom) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.onMenuSelected?.call(item);
        } else if (item == StudentMenuItem.inventory) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.onMenuSelected?.call(item);
        }
      },
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                if (_isTutorialPreferenceLoaded && _isTutorialVisible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _TutorialGuideCard(
                          step:
                              _tutorialSteps[_tutorialStepIndex
                                  .clamp(0, _tutorialSteps.length - 1)
                                  .toInt()],
                          stepNumber: _tutorialStepIndex + 1,
                          stepCount: _tutorialSteps.length,
                          onPrevious: () => _advanceTutorial(-1),
                          onNext: () =>
                              _tutorialStepIndex == _tutorialSteps.length - 1
                              ? _dismissTutorial()
                              : _advanceTutorial(1),
                          onDismiss: _dismissTutorial,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _setupScrollController,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _tutorialTarget(
                              _TutorialStep.learningMode,
                              _LearningModePanel(
                                selectedMode: _selectedMode,
                                onChanged: (mode) => setState(() {
                                  _selectedMode = mode;
                                  _quizNameController.clear();
                                }),
                              ),
                              key:
                                  _tutorialTargetKeys[_TutorialStep
                                      .learningMode],
                            ),
                            const SizedBox(height: 16),
                            _tutorialTarget(
                              _TutorialStep.sourceFile,
                              _FilePickerPanel(
                                selectedFile: _selectedFile,
                                quizNameController: _quizNameController,
                                activityName: _activityName,
                                isDragHovered: _isDragHovered,
                                useWebDropzone: kIsWeb,
                                onPick: _pickFile,
                                onClear: _clearFile,
                                onDragHover: () => _setDragHovered(true),
                                onDragLeave: () => _setDragHovered(false),
                                onDropFiles: _handleDroppedFiles,
                                onDropzoneCreated: (controller) =>
                                    _dropzoneController = controller,
                                onWebDropFile: _handleWebDroppedFile,
                              ),
                              key:
                                  _tutorialTargetKeys[_TutorialStep.sourceFile],
                            ),
                            if (_selectedMode == _LearningMode.quiz) ...[
                              const SizedBox(height: 16),
                              _tutorialTarget(
                                _TutorialStep.questionType,
                                _QuestionTypesPanel(
                                  selectedTypes: _selectedTypes,
                                  onChanged: (type) => setState(() {
                                    if (_selectedTypes.contains(type)) {
                                      if (_selectedTypes.length > 1) {
                                        _selectedTypes.remove(type);
                                      }
                                    } else {
                                      _selectedTypes.add(type);
                                    }
                                  }),
                                ),
                                key:
                                    _tutorialTargetKeys[_TutorialStep
                                        .questionType],
                              ),
                            ],
                            const SizedBox(height: 16),
                            _tutorialTarget(
                              _TutorialStep.itemCount,
                              _ItemCountPanel(
                                selectedCount: _selectedItemCount,
                                onChanged: (count) =>
                                    setState(() => _selectedItemCount = count),
                              ),
                              key: _tutorialTargetKeys[_TutorialStep.itemCount],
                            ),
                            const SizedBox(height: 24),
                            _tutorialTarget(
                              _TutorialStep.generate,
                              _GenerateButton(
                                onPressed: _generate,
                                isLoading: _isGenerating,
                                isEnabled: _selectedFile != null,
                              ),
                              key: _tutorialTargetKeys[_TutorialStep.generate],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isGenerating)
              Positioned.fill(
                child: _GenerationLoadingOverlay(
                  status: _generationStatus ?? 'Getting things ready...',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tutorialTarget(
    _TutorialStep step,
    Widget child, {
    required GlobalKey? key,
  }) {
    final active =
        _isTutorialVisible &&
        _isTutorialPreferenceLoaded &&
        _tutorialSteps[_tutorialStepIndex
                .clamp(0, _tutorialSteps.length - 1)
                .toInt()] ==
            step;
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 220),
      padding: active ? const EdgeInsets.all(4) : EdgeInsets.zero,
      decoration: BoxDecoration(
        border: active ? Border.all(color: _primary, width: 2) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.14),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _inputFill,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'CREATE A QUIZ',
            style: TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Turn your notes into a focused study session',
          style: TextStyle(
            color: _heading,
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a learning mode, select the number of items, and start learning.',
          style: TextStyle(fontSize: 16, height: 1.5, color: _subtle),
        ),
      ],
    );
  }
}

enum _TutorialStep {
  start,
  learningMode,
  sourceFile,
  questionType,
  itemCount,
  generate,
}

class _GenerationLoadingOverlay extends StatefulWidget {
  const _GenerationLoadingOverlay({required this.status});

  final String status;

  @override
  State<_GenerationLoadingOverlay> createState() =>
      _GenerationLoadingOverlayState();
}

class _GenerationLoadingOverlayState extends State<_GenerationLoadingOverlay> {
  final math.Random _random = math.Random();
  Timer? _tipTimer;
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _tipIndex = _random.nextInt(_learningTips.length);
    _tipTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      var nextIndex = _tipIndex;
      while (nextIndex == _tipIndex) {
        nextIndex = _random.nextInt(_learningTips.length);
      }
      setState(() => _tipIndex = nextIndex);
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _learningTips[_tipIndex];
    return ColoredBox(
      color: const Color(0xFFF9F5F0),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Preparing your study session',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _heading.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _inputFill,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: _primary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Preparing your study session',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _heading,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Semantics(
                        key: ValueKey(widget.status),
                        liveRegion: true,
                        child: Text(
                          widget.status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _subtle,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const LinearProgressIndicator(
                        minHeight: 7,
                        backgroundColor: _inputFill,
                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF5E7D7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                color: _primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'A QUICK LEARNING TIP',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.08),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: Column(
                              key: ValueKey(_tipIndex),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.title,
                                  style: const TextStyle(
                                    color: _heading,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tip.description,
                                  style: const TextStyle(
                                    color: _subtle,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningTip {
  const _LearningTip(this.title, this.description);

  final String title;
  final String description;
}

const _learningTips = [
  _LearningTip(
    'Try recalling, not just rereading',
    'Close your notes and try to explain the main idea from memory.',
  ),
  _LearningTip(
    'Space out your practice',
    'Short study sessions spread over time can help knowledge stick.',
  ),
  _LearningTip(
    'Teach it in your own words',
    'Explaining a concept simply can reveal what you understand and what to revisit.',
  ),
  _LearningTip(
    'Mix up your practice',
    'Switching between related topics helps you practice choosing the right approach.',
  ),
  _LearningTip(
    'Break big topics into steps',
    'Focus on one manageable piece at a time, then connect the pieces together.',
  ),
  _LearningTip(
    'Use examples you can picture',
    'Connecting an abstract idea to a concrete example makes it easier to work with.',
  ),
  _LearningTip(
    'Take a short reset',
    'A brief break between focused study blocks can help you return with fresh attention.',
  ),
  _LearningTip(
    'Ask yourself: why?',
    'Linking new ideas to what you already know makes them more meaningful.',
  ),
  _LearningTip(
    'Sleep is part of studying',
    'Rest supports memory and attention, so make room for it in your routine.',
  ),
  _LearningTip(
    'Set one clear study goal',
    'Decide what you want to understand before you begin to keep your session focused.',
  ),
];

class _TutorialGuideCard extends StatelessWidget {
  const _TutorialGuideCard({
    required this.step,
    required this.stepNumber,
    required this.stepCount,
    required this.onPrevious,
    required this.onNext,
    required this.onDismiss,
  });

  final _TutorialStep step;
  final int stepNumber;
  final int stepCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDismiss;

  String get _title => switch (step) {
    _TutorialStep.start => 'Welcome to your first study session',
    _TutorialStep.learningMode => 'Choose a learning mode',
    _TutorialStep.sourceFile => 'Bring your study material',
    _TutorialStep.questionType => 'Pick your question style',
    _TutorialStep.itemCount => 'Set your session length',
    _TutorialStep.generate => 'You’re ready to learn',
  };

  String get _description => switch (step) {
    _TutorialStep.start =>
      'You’re already here, so let’s set up your first quiz or practice activity together.',
    _TutorialStep.learningMode =>
      'Choose Quiz to test what you know, Flashcards to practice recall, or Matching to connect related ideas.',
    _TutorialStep.sourceFile =>
      'Upload a PDF, DOCX, or TXT file with your notes. We’ll use it as the source for your study activity.',
    _TutorialStep.questionType =>
      'For quizzes, choose multiple choice, true or false, or both. You can keep the suggested option or mix formats.',
    _TutorialStep.itemCount =>
      'Choose how many questions or practice items you want in this session.',
    _TutorialStep.generate =>
      'Give your activity a name, then select Generate Quiz to create it. You can update any choice before you begin.',
  };

  @override
  Widget build(BuildContext context) {
    final isFirst = stepNumber == 1;
    final isLast = stepNumber == stepCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0D7C5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR QUICK START  ·  $stepNumber OF $stepCount',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _title,
                      style: const TextStyle(
                        color: _heading,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss tutorial',
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, color: _subtle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _description,
            style: const TextStyle(color: _subtle, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: stepNumber / stepCount,
              minHeight: 4,
              backgroundColor: const Color(0xFFF4E6DA),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('Skip tutorial'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isFirst)
                    TextButton(
                      onPressed: onPrevious,
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: onNext,
                    child: Text(isLast ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilePickerPanel extends StatelessWidget {
  const _FilePickerPanel({
    required this.selectedFile,
    required this.quizNameController,
    required this.activityName,
    required this.isDragHovered,
    required this.useWebDropzone,
    required this.onPick,
    required this.onClear,
    required this.onDragHover,
    required this.onDragLeave,
    required this.onDropFiles,
    required this.onDropzoneCreated,
    required this.onWebDropFile,
  });

  final PlatformFile? selectedFile;
  final TextEditingController quizNameController;
  final String activityName;
  final bool isDragHovered;
  final bool useWebDropzone;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onDragHover;
  final VoidCallback onDragLeave;
  final ValueChanged<DropDoneDetails> onDropFiles;
  final ValueChanged<DropzoneViewController> onDropzoneCreated;
  final ValueChanged<DropzoneFileInterface> onWebDropFile;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.upload_file_outlined,
      title: 'Source File',
      description: 'Upload a file and name your $activityName',
      child: selectedFile == null
          ? _buildDropZone()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileInfo(),
                const SizedBox(height: 16),
                TextField(
                  controller: quizNameController,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText:
                        '${activityName[0].toUpperCase()}${activityName.substring(1)} name',
                    hintText: 'Enter a name for your $activityName',
                    prefixIcon: const Icon(
                      Icons.edit_outlined,
                      color: _primary,
                    ),
                    filled: true,
                    fillColor: _inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDropZone() {
    final contents = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isDragHovered ? const Color(0xFFFFE3D4) : _inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragHovered ? _primary : _border,
          width: isDragHovered ? 2.5 : 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: _primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isDragHovered
                ? 'Drop your file to upload'
                : 'Drag & drop a file here',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _heading,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Supported: PDF, DOCX, TXT (max 3 MB)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _subtle),
          ),
        ],
      ),
    );

    return Column(
      children: [
        if (useWebDropzone)
          SizedBox(
            height: 172,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DropzoneView(
                    operation: DragOperation.copy,
                    onCreated: onDropzoneCreated,
                    onHover: onDragHover,
                    onLeave: onDragLeave,
                    onDropFile: onWebDropFile,
                    onDropInvalid: (_) => onDragLeave(),
                  ),
                  IgnorePointer(child: contents),
                ],
              ),
            ),
          )
        else
          DropTarget(
            onDragEntered: (_) => onDragHover(),
            onDragExited: (_) => onDragLeave(),
            onDragDone: onDropFiles,
            child: contents,
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            backgroundColor: Colors.white,
          ),
          child: const Text('Browse files'),
        ),
      ],
    );
  }

  Widget _buildFileInfo() {
    final file = selectedFile!;
    final extension = file.extension?.toUpperCase() ?? 'FILE';
    final size = _formatFileSize(file.size);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: _FileTypeIcon(extension: extension),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        extension,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(size, style: TextStyle(fontSize: 13, color: _subtle)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: _subtle),
            tooltip: 'Remove file',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _subtle,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.extension});

  final String extension;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (extension.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf_rounded;
        color = const Color(0xFFFF4444);
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description_rounded;
        color = const Color(0xFF2A56C6);
        break;
      case 'txt':
        icon = Icons.text_snippet_rounded;
        color = _primary;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = _subtle;
    }

    return Icon(icon, color: color, size: 28);
  }
}

enum _LearningMode { quiz, flashcards, matching }

class _LearningModePanel extends StatelessWidget {
  const _LearningModePanel({
    required this.selectedMode,
    required this.onChanged,
  });

  final _LearningMode selectedMode;
  final ValueChanged<_LearningMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.style_outlined,
      title: 'Learning Mode',
      description: 'Choose how you want to study',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final choices = _LearningMode.values
              .map(
                (mode) => _LearningModeChoice(
                  mode: mode,
                  selected: mode == selectedMode,
                  onTap: () => onChanged(mode),
                ),
              )
              .toList(growable: false);
          if (constraints.maxWidth < 580) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < choices.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  choices[index],
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < choices.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(child: choices[index]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LearningModeChoice extends StatelessWidget {
  const _LearningModeChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final _LearningMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, description, icon) = switch (mode) {
      _LearningMode.quiz => (
        'Quiz',
        'Test your knowledge',
        Icons.checklist_rounded,
      ),
      _LearningMode.flashcards => (
        'Flashcards',
        'Recall concepts',
        Icons.style_rounded,
      ),
      _LearningMode.matching => (
        'Matching',
        'Pair concepts',
        Icons.extension_rounded,
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        key: ValueKey('learning-mode-${mode.name}'),
        duration: const Duration(milliseconds: 220),
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _primary : _inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _primary : _border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : _heading, size: 24),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : _heading,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white.withValues(alpha: 0.9) : _subtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTypesPanel extends StatelessWidget {
  const _QuestionTypesPanel({
    required this.selectedTypes,
    required this.onChanged,
  });

  final Set<QuizQuestionType> selectedTypes;
  final ValueChanged<QuizQuestionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.quiz_outlined,
      title: 'Question Types',
      description: 'Choose one or both question formats for your quiz',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: QuizQuestionType.values.map((type) {
          final isSelected = selectedTypes.contains(type);
          return _QuestionTypeChip(
            type: type,
            isSelected: isSelected,
            onTap: () => onChanged(type),
          );
        }).toList(),
      ),
    );
  }
}

class _QuestionTypeChip extends StatelessWidget {
  const _QuestionTypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final QuizQuestionType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type.icon,
              color: isSelected ? Colors.white : _primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              type.label,
              style: TextStyle(
                color: isSelected ? Colors.white : _heading,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on QuizQuestionType {
  String get label => switch (this) {
    QuizQuestionType.multipleChoice => 'Multiple Choice',
    QuizQuestionType.trueOrFalse => 'True or False',
  };

  IconData get icon => switch (this) {
    QuizQuestionType.multipleChoice => Icons.format_list_numbered_rounded,
    QuizQuestionType.trueOrFalse => Icons.check_circle_outline_rounded,
  };
}

class _ItemCountPanel extends StatelessWidget {
  const _ItemCountPanel({required this.selectedCount, required this.onChanged});

  final int selectedCount;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.numbers_outlined,
      title: 'Number of Items',
      description: 'Choose how many questions to generate',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [10, 20, 30];
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          final compact = constraints.maxWidth < 400 || isLandscape;
          return Row(
            children: items
                .expand(
                  (count) => [
                    Expanded(child: _buildRadioItem(count, compact: compact)),
                    if (count != items.last) SizedBox(width: compact ? 8 : 12),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildRadioItem(int count, {bool compact = false}) {
    final isSelected = selectedCount == count;
    return InkWell(
      onTap: () => onChanged(count),
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 12 : 24,
          horizontal: compact ? 4 : 16,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _inputFill,
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: compact ? 8 : 12,
                    offset: Offset(0, compact ? 2 : 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : _heading,
                fontSize: compact ? 24 : 32,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            SizedBox(height: compact ? 2 : 6),
            Text(
              count == 1 ? 'Item' : 'Items',
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : _subtle,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.onPressed,
    required this.isLoading,
    required this.isEnabled,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isEnabled ? 4 : 0,
          shadowColor: _primary.withValues(alpha: 0.4),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 24),
        label: Text(
          isLoading ? 'Generating...' : 'Generate Quiz',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      width: double.infinity,
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _heading,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: _subtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

enum _InstructorQuizAction { take, save }

class _InstructorQuizChoice extends StatelessWidget {
  const _InstructorQuizChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _subtle,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _primary,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
