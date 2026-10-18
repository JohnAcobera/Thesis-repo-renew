import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../../services/classroom_service.dart';
import '../../services/quiz_service.dart';
import '../quiz_screen.dart';

const _primary = Color(0xFFFF7434);
const _heading = Color(0xFF3B2419);
const _subtle = Color(0xFF765C4F);
const _border = Color(0xFFE8D7C2);
const _danger = Color(0xFFB42318);

Future<bool?> _showDeleteConfirmation(
  BuildContext context, {
  required String title,
  required String description,
  required String confirmLabel,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    icon: const Icon(Icons.warning_amber_rounded, color: _danger, size: 34),
    title: Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _heading, fontWeight: FontWeight.w700),
    ),
    content: Text(
      description,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _subtle, height: 1.45),
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.of(dialogContext).pop(false),
        style: OutlinedButton.styleFrom(
          foregroundColor: _subtle,
          side: const BorderSide(color: _border),
        ),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(true),
        style: FilledButton.styleFrom(backgroundColor: _danger),
        child: Text(confirmLabel),
      ),
    ],
  ),
);

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({
    required this.user,
    this.classroomService,
    this.initialClassroomId,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;
  final String? initialClassroomId;

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  late final ClassroomRepository _classroomService =
      widget.classroomService ?? ClassroomService();

  List<ClassroomModel> _classrooms = [];
  ClassroomModel? _selectedClassroom;
  bool _isLoading = true;
  bool _isDeletingClassroom = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final classrooms = _isStudent
          ? await _classroomService.listStudentClassrooms()
          : await _classroomService.listClassrooms();
      if (!mounted) return;
      ClassroomModel? initialClassroom;
      for (final classroom in classrooms) {
        if (classroom.id == widget.initialClassroomId) {
          initialClassroom = classroom;
          break;
        }
      }
      setState(() {
        _classrooms = classrooms;
        _selectedClassroom = initialClassroom;
        _isLoading = false;
      });
    } on ClassroomServiceException catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.message;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _loadError = 'Unable to load classrooms. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  bool get _isStudent => widget.user.role.toLowerCase() == 'student';

  Future<void> _showJoinClassroomForm() async {
    final classroom = await showDialog<ClassroomModel>(
      context: context,
      builder: (_) =>
          _JoinClassroomDialog(onJoin: _classroomService.joinClassroom),
    );

    if (classroom == null || !mounted) return;
    setState(() {
      _classrooms = [
        classroom,
        ..._classrooms.where((existing) => existing.id != classroom.id),
      ];
      _loadError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joined ${classroom.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showCreateClassroomForm() async {
    final classroom = await showDialog<ClassroomModel>(
      context: context,
      builder: (_) =>
          _CreateClassroomDialog(onCreate: _classroomService.createClassroom),
    );

    if (classroom != null) {
      if (!mounted) return;
      setState(() {
        _classrooms = [classroom, ..._classrooms];
        _loadError = null;
      });
      await _showClassroomCode(classroom);
    }
  }

  Future<void> _deleteClassroom(ClassroomModel classroom) async {
    final confirmed = await _showDeleteConfirmation(
      context,
      title: 'Delete classroom?',
      description:
          '“${classroom.name}” and its student memberships and posted quizzes '
          'will be permanently removed. This action cannot be undone.',
      confirmLabel: 'Delete classroom',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingClassroom = true);
    try {
      await _classroomService.deleteClassroom(classroom.id);
      if (!mounted) return;
      setState(() {
        _classrooms.removeWhere((item) => item.id == classroom.id);
        _selectedClassroom = null;
        _loadError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classroom deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ClassroomServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'The classroom could not be deleted. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingClassroom = false);
    }
  }

  Future<void> _showClassroomCode(ClassroomModel classroom) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFFFFF8EE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.check_circle_outline, color: _primary, size: 36),
      title: const Text(
        'Classroom created!',
        textAlign: TextAlign.center,
        style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            classroom.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _subtle),
          ),
          const SizedBox(height: 18),
          const Text(
            'Classroom code',
            style: TextStyle(color: _subtle, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5D5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              classroom.code,
              style: const TextStyle(
                color: _heading,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This code has been saved. Share it with your students when you are ready.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _subtle, fontSize: 13),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: _primary),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final classroom = _selectedClassroom;
    if (classroom != null) {
      return ClassroomDetailScreen(
        classroom: classroom,
        user: widget.user,
        classroomService: widget.classroomService ?? ClassroomService(),
        onBack: () => setState(() => _selectedClassroom = null),
        onDelete: _deleteClassroom,
        isDeleting: _isDeletingClassroom,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your classrooms',
                      style: TextStyle(
                        color: _heading,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isStudent
                        ? _showJoinClassroomForm
                        : _showCreateClassroomForm,
                    icon: Icon(_isStudent ? Icons.login : Icons.add, size: 19),
                    label: Text(
                      _isStudent ? 'Join classroom' : 'Create classroom',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: _primary),
                  ),
                )
              else if (_loadError != null)
                _ClassroomLoadError(
                  message: _loadError!,
                  onRetry: _loadClassrooms,
                )
              else if (_classrooms.isEmpty)
                const _EmptyClassrooms()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _classrooms.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        mainAxisExtent: 236,
                      ),
                      itemBuilder: (context, index) => _ClassroomCard(
                        classroom: _classrooms[index],
                        onTap: () => setState(
                          () => _selectedClassroom = _classrooms[index],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateClassroomDialog extends StatefulWidget {
  const _CreateClassroomDialog({required this.onCreate});

  final Future<ClassroomModel> Function({
    required String name,
    required String subject,
    required String iconKey,
  })
  onCreate;

  @override
  State<_CreateClassroomDialog> createState() => _CreateClassroomDialogState();
}

class _CreateClassroomDialogState extends State<_CreateClassroomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  String _selectedIconKey = 'book';
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });
    try {
      final classroom = await widget.onCreate(
        name: _nameController.text,
        subject: _subjectController.text,
        iconKey: _selectedIconKey,
      );
      if (mounted) Navigator.of(context).pop(classroom);
    } on ClassroomServiceException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _isCreating = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage =
              'The classroom could not be created. Please try again.';
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFF8EE),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text(
      'Create classroom',
      style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
    ),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClassroomTextField(
              controller: _nameController,
              label: 'Class name',
              hint: 'e.g., Grade 11 - STEM A',
            ),
            const SizedBox(height: 16),
            _ClassroomTextField(
              controller: _subjectController,
              label: 'Subject / Course',
              hint: 'e.g., General Biology 1',
            ),
            const SizedBox(height: 16),
            const Text(
              'Classroom icon',
              style: TextStyle(color: _heading, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in ClassroomModel.iconOptions)
                  ChoiceChip(
                    avatar: Icon(option.icon, size: 18),
                    label: Text(option.label),
                    selected: _selectedIconKey == option.key,
                    onSelected: _isCreating
                        ? null
                        : (_) => setState(() => _selectedIconKey = option.key),
                    selectedColor: const Color(0xFFFFE5D5),
                    tooltip: 'Use ${option.label} icon',
                  ),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFA33A2B)),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _isCreating ? null : _create,
        icon: _isCreating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Create classroom'),
        style: FilledButton.styleFrom(backgroundColor: _primary),
      ),
    ],
  );
}

class _JoinClassroomDialog extends StatefulWidget {
  const _JoinClassroomDialog({required this.onJoin});

  final Future<ClassroomModel> Function({required String code}) onJoin;

  @override
  State<_JoinClassroomDialog> createState() => _JoinClassroomDialogState();
}

class _JoinClassroomDialogState extends State<_JoinClassroomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });
    try {
      final classroom = await widget.onJoin(
        code: _codeController.text.trim().toUpperCase(),
      );
      if (mounted) Navigator.of(context).pop(classroom);
    } on ClassroomServiceException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _isJoining = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not join the classroom. Please try again.';
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFF8EE),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text(
      'Join classroom',
      style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
    ),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the classroom code shared by your instructor.',
              style: TextStyle(color: _subtle),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Classroom code',
                hintText: 'e.g., 2114C9D3B660',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a classroom code.'
                  : null,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFA33A2B)),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isJoining ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _isJoining ? null : _join,
        icon: _isJoining
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login),
        label: const Text('Join classroom'),
        style: FilledButton.styleFrom(backgroundColor: _primary),
      ),
    ],
  );
}

class _ClassroomTextField extends StatelessWidget {
  const _ClassroomTextField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: _heading, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        decoration: InputDecoration(hintText: hint),
        textCapitalization: TextCapitalization.sentences,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Please enter a ${label.toLowerCase()}.'
            : null,
      ),
    ],
  );
}

class _EmptyClassrooms extends StatelessWidget {
  const _EmptyClassrooms();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        const Icon(Icons.class_outlined, color: _primary, size: 42),
        const SizedBox(height: 14),
        const Text(
          'No classrooms yet',
          style: TextStyle(
            color: _heading,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Create a classroom to get started.',
          style: TextStyle(color: _subtle),
        ),
      ],
    ),
  );
}

class _ClassroomLoadError extends StatelessWidget {
  const _ClassroomLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.classroom, required this.onTap});

  final ClassroomModel classroom;
  final VoidCallback onTap;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: classroom.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Classroom code copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0DDCC)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x083B2419),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5D5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(classroom.icon, color: _primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    classroom.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              classroom.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _subtle, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ClassroomSummaryChip(
                    icon: Icons.people_alt_outlined,
                    label:
                        '${classroom.studentCount} '
                        '${classroom.studentCount == 1 ? 'student' : 'students'}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ClassroomSummaryChip(
                    icon: Icons.assignment_outlined,
                    label:
                        '${classroom.activityCount} '
                        '${classroom.activityCount == 1 ? 'activity' : 'activities'}',
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.key_outlined, color: _primary, size: 17),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Code: ${classroom.code}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _heading,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy classroom code',
                  onPressed: () => _copyCode(context),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  color: _primary,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClassroomSummaryChip extends StatelessWidget {
  const _ClassroomSummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF6EF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF3E5D9)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _heading,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class ClassroomDetailScreen extends StatelessWidget {
  const ClassroomDetailScreen({
    required this.classroom,
    required this.user,
    required this.classroomService,
    required this.onBack,
    required this.onDelete,
    required this.isDeleting,
    super.key,
  });

  final ClassroomModel classroom;
  final UserModel user;
  final ClassroomRepository classroomService;
  final VoidCallback onBack;
  final Future<void> Function(ClassroomModel) onDelete;
  final bool isDeleting;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: classroom.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Classroom code copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Your classrooms'),
                      style: TextButton.styleFrom(foregroundColor: _primary),
                    ),
                  ),
                ),
                if (user.role.toLowerCase() == 'instructor')
                  OutlinedButton.icon(
                    onPressed: isDeleting ? null : () => onDelete(classroom),
                    icon: isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _danger,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(isDeleting ? 'Deleting…' : 'Delete classroom'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _danger,
                      side: const BorderSide(color: Color(0xFFE7B8B4)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5D5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(classroom.icon, size: 28, color: _primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classroom.name,
                              style: const TextStyle(
                                color: _heading,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              classroom.subject,
                              style: const TextStyle(
                                color: _subtle,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final studentCount = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.groups_outlined,
                            color: _primary,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${classroom.studentCount} ${classroom.studentCount == 1 ? 'student' : 'students'}',
                            style: const TextStyle(
                              color: _heading,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      );
                      final joinCode = Row(
                        children: [
                          const Icon(
                            Icons.key_outlined,
                            color: _primary,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Join code: ${classroom.code}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _heading,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy classroom code',
                            onPressed: () => _copyCode(context),
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            color: _primary,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            studentCount,
                            const SizedBox(height: 12),
                            joinCode,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          studentCount,
                          const SizedBox(width: 20),
                          Expanded(child: joinCode),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _PostActivitiesSection(
              classroom: classroom,
              user: user,
              classroomService: classroomService,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PostActivitiesSection extends StatefulWidget {
  const _PostActivitiesSection({
    required this.classroom,
    required this.user,
    required this.classroomService,
  });

  final ClassroomModel classroom;
  final UserModel user;
  final ClassroomRepository classroomService;

  @override
  State<_PostActivitiesSection> createState() => _PostActivitiesSectionState();
}

class _PostActivitiesSectionState extends State<_PostActivitiesSection> {
  late Future<List<ClassroomActivity>> _activities;
  late final Timer _availabilityTimer;
  String? _deletingActivityId;

  @override
  void initState() {
    super.initState();
    _activities = widget.classroomService.classroomActivities(
      widget.classroom.id,
    );
    _availabilityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _availabilityTimer.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _activities = widget.classroomService.classroomActivities(
        widget.classroom.id,
      );
    });
  }

  Future<void> _deleteActivity(ClassroomActivity activity) async {
    final confirmed = await _showDeleteConfirmation(
      context,
      title: 'Delete posted quiz?',
      description:
          '“${activity.title}” will no longer be available to students in '
          'this classroom. This action cannot be undone.',
      confirmLabel: 'Delete quiz',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingActivityId = activity.id);
    try {
      await widget.classroomService.deleteClassroomActivity(
        classroomId: activity.classroomId,
        activityId: activity.id,
      );
      if (!mounted) return;
      _retry();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Posted quiz deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ClassroomServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'The posted quiz could not be deleted. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingActivityId = null);
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} at '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Post Activities',
                style: TextStyle(
                  color: _heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh activities',
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, color: _primary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Activities shared with this classroom appear here.',
          style: TextStyle(color: _subtle, fontSize: 13),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ClassroomActivity>>(
          future: _activities,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: _primary),
                ),
              );
            }
            if (snapshot.hasError) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Could not load classroom activities. Please try again.',
                      style: const TextStyle(color: _subtle),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              );
            }
            final activities = snapshot.data ?? const <ClassroomActivity>[];
            if (activities.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      color: Color(0xFFC49A7E),
                      size: 30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nothing posted here yet',
                      style: TextStyle(
                        color: _heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'New classroom activities will show up in this space.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _subtle, fontSize: 12),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final activity in activities)
                  _ClassroomActivityTile(
                    activity: activity,
                    user: widget.user,
                    formatDateTime: _formatDateTime,
                    onActivityCompleted: _retry,
                    isDeleting: _deletingActivityId == activity.id,
                    onDelete: () => _deleteActivity(activity),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ClassroomActivityTile extends StatelessWidget {
  const _ClassroomActivityTile({
    required this.activity,
    required this.user,
    required this.formatDateTime,
    required this.onActivityCompleted,
    required this.isDeleting,
    required this.onDelete,
  });

  final ClassroomActivity activity;
  final UserModel user;
  final String Function(DateTime) formatDateTime;
  final VoidCallback onActivityCompleted;
  final bool isDeleting;
  final VoidCallback onDelete;

  Future<void> _openActivity(BuildContext context) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuizScreen(
          username: user.fullName,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt,
          title: activity.title,
          sourceFile: activity.sourceFile,
          questions: activity.questions,
          quizId: activity.quizId,
          classroomActivityId: activity.id,
          previousAttempts: activity.attempts,
        ),
      ),
    );
    if (completed == true) onActivityCompleted();
  }

  Future<void> _showPreview(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
                child: Row(
                  children: [
                    const Icon(Icons.quiz_outlined, color: _primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _heading,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${activity.questions.length} questions · '
                            '${activity.maxAttempts} attempts per student',
                            style: const TextStyle(
                              color: _subtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: activity.questions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final question = activity.questions[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUESTION ${index + 1}',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            question.question,
                            style: const TextStyle(
                              color: _heading,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (
                            var optionIndex = 0;
                            optionIndex < question.options.length;
                            optionIndex++
                          ) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    optionIndex == question.answerIndex
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 17,
                                    color: optionIndex == question.answerIndex
                                        ? const Color(0xFF578258)
                                        : _subtle,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      question.options[optionIndex],
                                      style: TextStyle(
                                        color: _heading,
                                        fontWeight:
                                            optionIndex == question.answerIndex
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (optionIndex == question.answerIndex)
                                    const Text(
                                      'Correct answer',
                                      style: TextStyle(
                                        color: Color(0xFF578258),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5E8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Explanation  ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: question.explanation),
                                ],
                              ),
                              style: const TextStyle(
                                color: _subtle,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isStudent = user.role.toLowerCase() == 'student';
    final isInstructor = user.role.toLowerCase() == 'instructor';
    final statusColor = switch (activity.status) {
      'Open' || 'In progress' || 'Completed' => const Color(0xFF578258),
      'Upcoming' => _primary,
      _ => const Color(0xFF8C6E5E),
    };
    final statusFill = switch (activity.status) {
      'Open' || 'In progress' || 'Completed' => const Color(0xFFEAF3E8),
      'Upcoming' => const Color(0xFFFFE9DC),
      _ => const Color(0xFFF4EDE7),
    };
    final information = Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9DC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: _primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusFill,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activity.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _ActivityScheduleLabel(
                    icon: Icons.play_arrow_rounded,
                    text: 'Opens ${formatDateTime(activity.startsAt)}',
                  ),
                  _ActivityScheduleLabel(
                    icon: Icons.event_outlined,
                    text: 'Due ${formatDateTime(activity.deadlineAt)}',
                  ),
                  if (isStudent)
                    _ActivityScheduleLabel(
                      icon: Icons.replay_rounded,
                      text:
                          '${activity.attemptCount} of '
                          '${activity.maxAttempts} attempts used',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final action = isStudent
        ? activity.status == 'Completed'
              ? const Text(
                  'No attempts left',
                  style: TextStyle(
                    color: _subtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : FilledButton(
                  onPressed: activity.isAvailable
                      ? () => _openActivity(context)
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: Text(
                    activity.attemptCount > 0
                        ? 'Retake activity'
                        : 'Take activity',
                  ),
                )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'View quiz',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (isInstructor) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Delete posted quiz',
                  onPressed: isDeleting ? null : onDelete,
                  visualDensity: VisualDensity.compact,
                  color: _danger,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _danger,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ],
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isStudent ? null : () => _showPreview(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x083B2419),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    information,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: information),
                  const SizedBox(width: 12),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActivityScheduleLabel extends StatelessWidget {
  const _ActivityScheduleLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFF9A806F), size: 14),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _subtle, fontSize: 11),
        ),
      ),
    ],
  );
}
