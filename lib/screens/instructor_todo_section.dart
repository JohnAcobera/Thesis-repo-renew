import 'package:flutter/material.dart';

import '../models/instructor_todo_task.dart';
import '../services/instructor_todo_service.dart';
import '../widgets/app_glass_surface.dart';

const _todoAccent = Color(0xFFF4773C);
const _todoInk = Color(0xFF3B2419);
const _todoMuted = Color(0xFF765C4F);
const _todoBorder = Color(0xFFE8D7C2);

enum _TodoFilter { all, open, completed }

extension on InstructorTodoPriority {
  String get label => switch (this) {
    InstructorTodoPriority.high => 'High',
    InstructorTodoPriority.normal => 'Normal',
    InstructorTodoPriority.low => 'Low',
  };
}

class InstructorTodoSection extends StatefulWidget {
  const InstructorTodoSection({
    required this.instructorId,
    this.repository,
    this.studentMode = false,
    this.panelHeight = 440,
    super.key,
  });

  final int instructorId;
  final InstructorTodoRepository? repository;
  final bool studentMode;
  final double panelHeight;

  @override
  State<InstructorTodoSection> createState() => _InstructorTodoSectionState();
}

class _InstructorTodoSectionState extends State<InstructorTodoSection> {
  late final InstructorTodoRepository _repository =
      widget.repository ?? const InstructorTodoService();
  late Future<List<InstructorTodoTask>> _tasks;
  _TodoFilter _filter = _TodoFilter.open;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tasks = _repository.listTasks(widget.instructorId);
  }

  Future<void> _addTask() async {
    final draft = await showDialog<_TodoDraft>(
      context: context,
      builder: (_) => _TodoDraftDialog(studentMode: widget.studentMode),
    );
    if (draft == null || !mounted) return;
    final currentTasks = await _tasks;
    if (!mounted) return;
    final task = InstructorTodoTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title,
      notes: draft.notes,
      dueDate: draft.dueDate,
      priority: draft.priority,
    );
    await _saveTasks([task, ...currentTasks]);
    if (mounted) setState(() => _filter = _TodoFilter.open);
  }

  Future<void> _toggleTask(
    InstructorTodoTask task,
    List<InstructorTodoTask> tasks,
  ) => _saveTasks([
    for (final item in tasks)
      if (item.id == task.id)
        item.copyWith(isCompleted: !item.isCompleted)
      else
        item,
  ]);

  Future<void> _removeTask(
    InstructorTodoTask task,
    List<InstructorTodoTask> tasks,
  ) async {
    await _saveTasks(tasks.where((item) => item.id != task.id).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('“${task.title}” removed from your list'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveTasks(List<InstructorTodoTask> tasks) async {
    setState(() => _isSaving = true);
    try {
      await _repository.saveTasks(widget.instructorId, tasks);
      if (mounted) {
        setState(() {
          _tasks = Future.value(tasks);
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Your task could not be saved: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retryLoading() {
    setState(() {
      _tasks = _repository.listTasks(widget.instructorId);
    });
  }

  DateTime _calendarDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('instructor-todo-panel'),
    height: widget.panelHeight,
    child: AppGlassSurface(
      borderRadius: 16,
      padding: const EdgeInsets.all(18),
      width: double.infinity,
      child: FutureBuilder<List<InstructorTodoTask>>(
        future: _tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _TodoLoadError(onRetry: _retryLoading);
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _todoAccent),
            );
          }

          final tasks = [...snapshot.data!]
            ..sort((a, b) {
              if (a.isCompleted != b.isCompleted) {
                return a.isCompleted ? 1 : -1;
              }
              final dueOrder = _calendarDate(
                a.dueDate,
              ).compareTo(_calendarDate(b.dueDate));
              if (dueOrder != 0) return dueOrder;
              return a.priority.index.compareTo(b.priority.index);
            });
          final openCount = tasks.where((task) => !task.isCompleted).length;
          final completedCount = tasks.length - openCount;
          final now = _calendarDate(DateTime.now());
          final dueSoonCount = tasks.where((task) {
            if (task.isCompleted) return false;
            final days = _calendarDate(task.dueDate).difference(now).inDays;
            return days >= 0 && days <= 1;
          }).length;
          final overdueCount = tasks.where((task) {
            return !task.isCompleted &&
                _calendarDate(task.dueDate).isBefore(now);
          }).length;
          final visibleTasks = tasks
              .where((task) {
                return switch (_filter) {
                  _TodoFilter.all => true,
                  _TodoFilter.open => !task.isCompleted,
                  _TodoFilter.completed => task.isCompleted,
                };
              })
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My tasks',
                      style: TextStyle(
                        color: _todoInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: const ValueKey('add-instructor-task'),
                    tooltip: 'Add task',
                    onPressed: _isSaving ? null : _addTask,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: _todoAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: _todoBorder),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: tasks.isEmpty
                            ? 0
                            : completedCount / tasks.length,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFFFE9DA),
                        color: _todoAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$completedCount of ${tasks.length} done',
                    style: const TextStyle(color: _todoMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  _TodoFilterChip(
                    label: 'All ${tasks.length}',
                    selected: _filter == _TodoFilter.all,
                    onSelected: () => setState(() => _filter = _TodoFilter.all),
                  ),
                  _TodoFilterChip(
                    label: 'To do $openCount',
                    selected: _filter == _TodoFilter.open,
                    onSelected: () =>
                        setState(() => _filter = _TodoFilter.open),
                  ),
                  _TodoFilterChip(
                    label: 'Done $completedCount',
                    selected: _filter == _TodoFilter.completed,
                    onSelected: () =>
                        setState(() => _filter = _TodoFilter.completed),
                  ),
                ],
              ),
              if (dueSoonCount > 0 || overdueCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: overdueCount > 0
                        ? const Color(0xFFFFEFEC)
                        : const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        overdueCount > 0
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_active_outlined,
                        size: 16,
                        color: overdueCount > 0
                            ? const Color(0xFFB84735)
                            : _todoAccent,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          [
                            if (dueSoonCount > 0)
                              '$dueSoonCount ${dueSoonCount == 1 ? 'task' : 'tasks'} due today or tomorrow',
                            if (overdueCount > 0)
                              '$overdueCount overdue ${overdueCount == 1 ? 'task' : 'tasks'}',
                          ].join(' · '),
                          style: TextStyle(
                            color: overdueCount > 0
                                ? const Color(0xFF9E3C2E)
                                : _todoInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: visibleTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tasks.isEmpty
                                  ? Icons.checklist_rounded
                                  : Icons.done_all_rounded,
                              color: const Color(0xFFC6A994),
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tasks.isEmpty
                                  ? widget.studentMode
                                        ? 'Plan a future study session'
                                        : 'Plan your next teaching task'
                                  : 'Nothing in this view',
                              style: const TextStyle(
                                color: _todoInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tasks.isEmpty
                                  ? 'Add a reminder for what needs doing next.'
                                  : 'Choose another filter to see your tasks.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _todoMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('instructor-task-list'),
                        padding: EdgeInsets.zero,
                        itemCount: visibleTasks.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: _todoBorder),
                        itemBuilder: (context, index) {
                          final task = visibleTasks[index];
                          final daysUntilDue = _calendarDate(
                            task.dueDate,
                          ).difference(now).inDays;
                          final dueLabel = switch (daysUntilDue) {
                            < 0 => 'Overdue',
                            0 => 'Today',
                            1 => 'Tomorrow',
                            _ => _formatDate(task.dueDate),
                          };
                          final priorityColor = switch (task.priority) {
                            InstructorTodoPriority.high => const Color(
                              0xFFB84735,
                            ),
                            InstructorTodoPriority.normal => _todoAccent,
                            InstructorTodoPriority.low => _todoMuted,
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 34,
                                  child: Checkbox(
                                    key: ValueKey('task-check-${task.id}'),
                                    value: task.isCompleted,
                                    activeColor: _todoAccent,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: _isSaving
                                        ? null
                                        : (_) => _toggleTask(task, tasks),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: task.isCompleted
                                              ? _todoMuted
                                              : _todoInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (task.notes.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          task.notes,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _todoMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.event_outlined,
                                            size: 12,
                                            color: daysUntilDue < 0
                                                ? const Color(0xFFB84735)
                                                : _todoMuted,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            task.dueDate.hour == 0 &&
                                                    task.dueDate.minute == 0
                                                ? dueLabel
                                                : '$dueLabel · ${_formatTime(task.dueDate)}',
                                            style: TextStyle(
                                              color: daysUntilDue < 0
                                                  ? const Color(0xFFB84735)
                                                  : _todoMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: priorityColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            task.priority.label,
                                            style: TextStyle(
                                              color: priorityColor,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove ${task.title}',
                                  onPressed: _isSaving
                                      ? null
                                      : () => _removeTask(task, tasks),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: const Color(0xFF967968),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class StudentTodoSection extends StatelessWidget {
  const StudentTodoSection({
    required this.studentId,
    this.repository,
    super.key,
  });

  final int studentId;
  final InstructorTodoRepository? repository;

  @override
  Widget build(BuildContext context) => InstructorTodoSection(
    instructorId: studentId,
    repository: repository ?? const StudentTodoService(),
    studentMode: true,
  );
}

class _TodoFilterChip extends StatelessWidget {
  const _TodoFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    labelStyle: TextStyle(
      color: selected ? Colors.white : _todoMuted,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
    backgroundColor: const Color(0xFFFFFCF8),
    selectedColor: _todoAccent,
    side: BorderSide(color: selected ? _todoAccent : _todoBorder),
    padding: const EdgeInsets.symmetric(horizontal: 1),
  );
}

class _TodoLoadError extends StatelessWidget {
  const _TodoLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB84735)),
        const SizedBox(height: 8),
        const Text(
          'Your tasks could not be loaded.',
          style: TextStyle(color: _todoInk),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _TodoDraft {
  const _TodoDraft({
    required this.title,
    required this.notes,
    required this.dueDate,
    required this.priority,
  });

  final String title;
  final String notes;
  final DateTime dueDate;
  final InstructorTodoPriority priority;
}

class _TodoDraftDialog extends StatefulWidget {
  const _TodoDraftDialog({required this.studentMode});

  final bool studentMode;

  @override
  State<_TodoDraftDialog> createState() => _TodoDraftDialogState();
}

class _TodoDraftDialogState extends State<_TodoDraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _dueDate = _defaultDueDate();
  InstructorTodoPriority _priority = InstructorTodoPriority.normal;

  static DateTime _defaultDueDate() {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day + 1, 9);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(today) ? today : _dueDate,
      firstDate: today,
      lastDate: DateTime(now.year + 5, now.month, now.day),
      builder: _pickerTheme,
    );
    if (date != null) {
      setState(
        () => _dueDate = DateTime(
          date.year,
          date.month,
          date.day,
          _dueDate.hour,
          _dueDate.minute,
        ),
      );
    }
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
      builder: _pickerTheme,
    );
    if (time != null) {
      setState(
        () => _dueDate = DateTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: _todoAccent,
        onPrimary: Colors.white,
        surface: const Color(0xFFFFFCF8),
        onSurface: _todoInk,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: const Color(0xFFFFFCF8),
        headerBackgroundColor: _todoAccent,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFFFFFCF8),
        dialBackgroundColor: const Color(0xFFFFF1DF),
        dialHandColor: _todoAccent,
        hourMinuteColor: const Color(0xFFFFF1DF),
        dayPeriodColor: const Color(0xFFFFF1DF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    child: child!,
  );

  String _formatSelectedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatSelectedTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _TodoDraft(
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFFCF8),
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    title: Text(
      widget.studentMode ? 'Add study task' : 'Add teaching task',
      style: const TextStyle(
        color: _todoInk,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const ValueKey('instructor-task-title'),
              controller: _titleController,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Task',
                hintText: widget.studentMode
                    ? 'e.g., Review a topic'
                    : 'e.g., Review next week’s quiz',
                filled: true,
                fillColor: const Color(0xFFFFF7EC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                counterStyle: const TextStyle(color: _todoMuted, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a task' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLength: 240,
              minLines: 3,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                filled: true,
                fillColor: const Color(0xFFFFF7EC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                counterStyle: const TextStyle(color: _todoMuted, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            const Text(
              'Due date & time',
              style: TextStyle(
                color: _todoInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DueDateTimeButton(
                    key: const ValueKey('instructor-task-due-date'),
                    label: 'Date',
                    value: _formatSelectedDate(_dueDate),
                    icon: Icons.calendar_today_outlined,
                    onPressed: _chooseDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DueDateTimeButton(
                    key: const ValueKey('instructor-task-due-time'),
                    label: 'Time',
                    value: _formatSelectedTime(_dueDate),
                    icon: Icons.schedule_rounded,
                    onPressed: _chooseTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InstructorTodoPriority>(
              initialValue: _priority,
              decoration: InputDecoration(
                labelText: 'Priority',
                filled: true,
                fillColor: const Color(0xFFFFF7EC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: InstructorTodoPriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (priority) {
                if (priority != null) setState(() => _priority = priority);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('save-instructor-task'),
        onPressed: _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _todoAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: const Text('Add task'),
      ),
    ],
  );
}

class _DueDateTimeButton extends StatelessWidget {
  const _DueDateTimeButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF7EC),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: _todoBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _todoAccent),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: _todoMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _todoInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
