import 'package:flutter/material.dart';

import '../../models/admin_management.dart';
import '../../services/admin_management_service.dart';
import '../../widgets/app_glass_surface.dart';

enum AdminSection { dashboard, teachers, classrooms, students, activity }

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({required this.section, super.key});

  final AdminSection section;

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _service = AdminManagementService();
  final _searchController = TextEditingController();
  AdminManagementData? _data;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.load();
      if (mounted) setState(() => _data = data);
    } on AdminManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'admin management',
          context: ErrorDescription('while loading admin management data'),
        ),
      );
      if (mounted) {
        setState(() => _error = 'Unable to load admin data. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTeacher() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateTeacherDialog(onCreate: _service.createTeacher),
    );
    await _afterAccountSaved(created, 'Teacher account created.');
  }

  Future<void> _editUser(AdminManagedUser user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateTeacherDialog(
        user: user,
        onCreate: _service.createTeacher,
        onUpdate: _service.updateUser,
      ),
    );
    await _afterAccountSaved(saved, 'Account updated.');
  }

  Future<void> _afterAccountSaved(bool? saved, String message) async {
    if (saved != true || !mounted) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _toggleUser(AdminManagedUser user) async {
    final activating = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? 'Reactivate account?' : 'Deactivate account?'),
        content: Text(
          activating
              ? '${user.fullName} will be able to sign in again.'
              : '${user.fullName} will be signed out and unable to sign in. '
                    'Their classroom and learning history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(activating ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.setUserActive(userId: user.id, isActive: activating);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activating ? 'Account reactivated.' : 'Account deactivated.',
            ),
          ),
        );
      }
    } on AdminManagementException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'admin management',
          context: ErrorDescription('while updating an account status'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update account status.')),
        );
      }
    }
  }

  Future<void> _editClassroom(AdminManagedClassroom classroom) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditClassroomDialog(
        classroom: classroom,
        onSave: _service.updateClassroom,
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Classroom updated.')));
    }
  }

  Future<void> _viewClassroom(AdminManagedClassroom classroom) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ClassroomDetailsDialog(
        classroom: classroom,
        loadStudents: _service.classroomStudents,
        removeStudent: _service.removeClassroomStudent,
      ),
    );
    if (changed != true || !mounted) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classroom roster updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final title = switch (section) {
      AdminSection.teachers => 'Teachers',
      AdminSection.classrooms => 'Classrooms',
      AdminSection.students => 'Students',
      AdminSection.activity => 'Activity log',
      AdminSection.dashboard => 'Overview',
    };
    final subtitle = switch (section) {
      AdminSection.teachers =>
        'Create teacher accounts and manage access to the platform.',
      AdminSection.classrooms =>
        'Review classrooms, owners, and student enrollment across the platform.',
      AdminSection.students =>
        'Find student accounts and manage platform access.',
      AdminSection.activity => 'Review account changes made by administrators.',
      AdminSection.dashboard => '',
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF3B2419),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Color(0xFF725F53)),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Refresh $title',
                  onPressed: _isLoading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (section == AdminSection.teachers) ...[
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _createTeacher,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add teacher'),
                ),
              ),
            ],
            if (section != AdminSection.activity) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search ${title.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_error case final error?)
              _ManagementError(message: error, onRetry: _load)
            else if (_isLoading && _data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_data case final data?)
              _buildSection(section, data),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(AdminSection section, AdminManagementData data) {
    final query = _searchController.text.trim().toLowerCase();
    return switch (section) {
      AdminSection.teachers => _buildAccounts(
        data.teachers,
        query,
        emptyMessage: 'No teacher accounts yet. Add the first teacher.',
      ),
      AdminSection.students => _buildAccounts(
        data.students,
        query,
        emptyMessage: 'No student accounts found.',
      ),
      AdminSection.classrooms => _buildClassrooms(data.classrooms, query),
      AdminSection.activity => _buildActivity(data.activity),
      AdminSection.dashboard => const SizedBox.shrink(),
    };
  }

  Widget _buildAccounts(
    List<AdminManagedUser> users,
    String query, {
    required String emptyMessage,
  }) {
    final filtered = users
        .where((user) {
          return user.fullName.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        })
        .toList(growable: false);
    if (filtered.isEmpty) return _EmptyState(message: emptyMessage);

    return Column(
      children: [
        _ResultCount(count: filtered.length, label: 'accounts'),
        const SizedBox(height: 10),
        for (final user in filtered) ...[
          AppGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFFF1DF),
                foregroundColor: const Color(0xFFB54A22),
                child: Text(
                  user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
                ),
              ),
              title: Text(
                user.fullName,
                style: const TextStyle(
                  color: Color(0xFF3B2419),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${user.email}\n'
                  '${user.classroomCount} classrooms · Joined ${_date(user.createdAt)}',
                ),
              ),
              isThreeLine: true,
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  _StatusChip(isActive: user.isActive),
                  PopupMenuButton<String>(
                    tooltip: 'Manage account',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _editUser(user);
                      } else {
                        _toggleUser(user);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit account'),
                      ),
                      PopupMenuItem(
                        value: user.isActive ? 'deactivate' : 'reactivate',
                        child: Text(
                          user.isActive
                              ? 'Deactivate access'
                              : 'Reactivate access',
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildClassrooms(
    List<AdminManagedClassroom> classrooms,
    String query,
  ) {
    final filtered = classrooms
        .where((classroom) {
          return classroom.name.toLowerCase().contains(query) ||
              classroom.subject.toLowerCase().contains(query) ||
              classroom.teacherName.toLowerCase().contains(query) ||
              classroom.teacherEmail.toLowerCase().contains(query);
        })
        .toList(growable: false);
    if (filtered.isEmpty) {
      return const _EmptyState(message: 'No classrooms found.');
    }

    return Column(
      children: [
        _ResultCount(count: filtered.length, label: 'classrooms'),
        const SizedBox(height: 10),
        for (final classroom in filtered) ...[
          AppGlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2EC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: Color(0xFF42836D),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom.name,
                        style: const TextStyle(
                          color: Color(0xFF3B2419),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${classroom.subject} · ${classroom.studentCount} students',
                        style: const TextStyle(color: Color(0xFF725F53)),
                      ),
                      Text(
                        '${classroom.teacherName} · ${classroom.teacherEmail}',
                        style: const TextStyle(color: Color(0xFF8A796D)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      classroom.code,
                      style: const TextStyle(
                        color: Color(0xFF3B2419),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date(classroom.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF8A796D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'View classroom students',
                  onPressed: () => _viewClassroom(classroom),
                  icon: const Icon(Icons.people_outline_rounded),
                ),
                IconButton(
                  tooltip: 'Edit classroom',
                  onPressed: () => _editClassroom(classroom),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildActivity(List<AdminActivityEvent> events) {
    if (events.isEmpty) {
      return const _EmptyState(
        message: 'Administrative account changes will appear here.',
      );
    }
    return Column(
      children: [
        _ResultCount(count: events.length, label: 'recent events'),
        const SizedBox(height: 10),
        AppGlassCard(
          child: Column(
            children: [
              for (var index = 0; index < events.length; index++) ...[
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF1DF),
                    child: Icon(
                      Icons.history_rounded,
                      color: Color(0xFFB54A22),
                    ),
                  ),
                  title: Text(
                    events[index].action,
                    style: const TextStyle(
                      color: Color(0xFF3B2419),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${events[index].targetLabel}\n'
                    'By ${events[index].adminName} · '
                    '${_dateTime(events[index].createdAt)}',
                  ),
                  isThreeLine: true,
                ),
                if (index < events.length - 1)
                  const Divider(height: 1, indent: 72, endIndent: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassroomDetailsDialog extends StatefulWidget {
  const _ClassroomDetailsDialog({
    required this.classroom,
    required this.loadStudents,
    required this.removeStudent,
  });

  final AdminManagedClassroom classroom;
  final Future<List<AdminManagedClassroomStudent>> Function(String classroomId)
  loadStudents;
  final Future<void> Function({
    required String classroomId,
    required int studentId,
  })
  removeStudent;

  @override
  State<_ClassroomDetailsDialog> createState() =>
      _ClassroomDetailsDialogState();
}

class _ClassroomDetailsDialogState extends State<_ClassroomDetailsDialog> {
  List<AdminManagedClassroomStudent>? _students;
  String? _error;
  int? _removingStudentId;
  bool _isLoading = true;
  bool _hasRemovedStudents = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final students = await widget.loadStudents(widget.classroom.id);
      if (mounted) setState(() => _students = students);
    } on AdminManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'admin management',
          context: ErrorDescription('while loading classroom students'),
        ),
      );
      if (mounted) {
        setState(
          () => _error = 'Unable to load classroom students. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeStudent(AdminManagedClassroomStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
          '${student.fullName} will no longer be enrolled in '
          '“${widget.classroom.name}”. They can rejoin with the classroom code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove student'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _removingStudentId = student.id;
      _error = null;
    });
    try {
      await widget.removeStudent(
        classroomId: widget.classroom.id,
        studentId: student.id,
      );
      if (!mounted) return;
      setState(() {
        _students = _students!
            .where((item) => item.id != student.id)
            .toList(growable: false);
        _hasRemovedStudents = true;
      });
    } on AdminManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'admin management',
          context: ErrorDescription('while removing a classroom student'),
        ),
      );
      if (mounted) {
        setState(
          () => _error = 'Unable to remove the student. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _removingStudentId = null);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
    contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    title: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2EC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.meeting_room_outlined,
            color: Color(0xFF42836D),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.classroom.name,
                style: const TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Classroom details and enrollment',
                style: TextStyle(
                  color: Color(0xFF8A796D),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 540,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0E4D8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ClassroomInfoChip(
                      icon: Icons.menu_book_outlined,
                      label: widget.classroom.subject,
                    ),
                    _ClassroomInfoChip(
                      icon: Icons.key_outlined,
                      label: 'Code ${widget.classroom.code}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Color(0xFF725F53),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.classroom.teacherName} · '
                        '${widget.classroom.teacherEmail}',
                        style: const TextStyle(
                          color: Color(0xFF725F53),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Enrolled students',
                  style: TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_students?.length ?? widget.classroom.studentCount}',
                  style: const TextStyle(
                    color: Color(0xFF9A461F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error case final error?) ...[
            _ManagementErrorMessage(message: error),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _loadStudents,
                child: const Text('Try again'),
              ),
            ),
          ] else if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_students!.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 30,
                    color: Color(0xFF8A796D),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No students enrolled yet',
                    style: TextStyle(color: Color(0xFF725F53)),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.38,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _students!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final student = _students![index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF0E4D8)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFFFFF1DF),
                        foregroundColor: const Color(0xFFB54A22),
                        child: Text(
                          student.fullName.isEmpty
                              ? '?'
                              : student.fullName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(
                        student.fullName,
                        style: const TextStyle(
                          color: Color(0xFF3B2419),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.email,
                              style: const TextStyle(color: Color(0xFF725F53)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Joined ${_date(student.joinedAt)}',
                              style: const TextStyle(
                                color: Color(0xFF8A796D),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: IconButton.filledTonal(
                        tooltip: 'Remove student',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE8E2),
                          foregroundColor: const Color(0xFFA33A2B),
                        ),
                        onPressed: _removingStudentId == null
                            ? () => _removeStudent(student)
                            : null,
                        icon: _removingStudentId == student.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_remove_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _removingStudentId == null
            ? () => Navigator.pop(context, _hasRemovedStudents)
            : null,
        child: const Text('Done'),
      ),
    ],
  );
}

class _ClassroomInfoChip extends StatelessWidget {
  const _ClassroomInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF0E4D8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF725F53)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5D4A3F),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _EditClassroomDialog extends StatefulWidget {
  const _EditClassroomDialog({required this.classroom, required this.onSave});

  final AdminManagedClassroom classroom;
  final Future<void> Function({
    required String classroomId,
    required String name,
    required String subject,
  })
  onSave;

  @override
  State<_EditClassroomDialog> createState() => _EditClassroomDialogState();
}

class _EditClassroomDialogState extends State<_EditClassroomDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.classroom.name);
  late final _subject = TextEditingController(text: widget.classroom.subject);
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        classroomId: widget.classroom.id,
        name: _name.text,
        subject: _subject.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AdminManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'admin management',
          context: ErrorDescription('while updating a classroom'),
        ),
      );
      if (mounted) {
        setState(
          () => _error = 'Unable to update the classroom. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
    contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    title: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1DF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.edit_outlined, color: Color(0xFFB54A22)),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit classroom',
                style: TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Update the classroom name and subject.',
                style: TextStyle(
                  color: Color(0xFF8A796D),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Classroom name',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a classroom name.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a subject.'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ManagementErrorMessage(message: _error!),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _isSaving ? null : _submit,
        child: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save changes'),
      ),
    ],
  );
}

class _CreateTeacherDialog extends StatefulWidget {
  const _CreateTeacherDialog({
    required this.onCreate,
    this.user,
    this.onUpdate,
  });

  final Future<void> Function({
    required String fullName,
    required String email,
    required String password,
  })
  onCreate;
  final AdminManagedUser? user;
  final Future<void> Function({
    required int userId,
    required String fullName,
    required String email,
    String? password,
  })?
  onUpdate;

  @override
  State<_CreateTeacherDialog> createState() => _CreateTeacherDialogState();
}

class _CreateTeacherDialogState extends State<_CreateTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.fullName ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (widget.user case final user?) {
        await widget.onUpdate!(
          userId: user.id,
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.onCreate(
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on AdminManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'admin management',
          context: ErrorDescription('while creating a teacher account'),
        ),
      );
      if (mounted) {
        setState(
          () => _error = 'Unable to create the account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.user == null ? 'Create teacher account' : 'Edit account',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Enter the teacher\'s name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value == null ||
                          !RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.user == null
                        ? 'Initial password'
                        : 'New password',
                    helperText: widget.user == null
                        ? 'At least 8 characters. Share it securely.'
                        : 'Leave blank to keep the current password. '
                              'A new password signs out existing sessions.',
                  ),
                  validator: (value) =>
                      (widget.user == null &&
                              (value == null || value.length < 8)) ||
                          (value != null &&
                              value.isNotEmpty &&
                              value.length < 8)
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ManagementErrorMessage(message: _error!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.user == null ? 'Create account' : 'Save changes'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isActive ? const Color(0xFFE7F2EC) : const Color(0xFFFFE6E0),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isActive ? 'Active' : 'Inactive',
      style: TextStyle(
        color: isActive ? const Color(0xFF327252) : const Color(0xFFA33A2B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      '$count $label',
      style: const TextStyle(
        color: Color(0xFF725F53),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AppGlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF725F53)),
      ),
    ),
  );
}

class _ManagementError extends StatelessWidget {
  const _ManagementError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppGlassCard(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFA33A2B)),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _ManagementErrorMessage extends StatelessWidget {
  const _ManagementErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE6E0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFFA33A2B))),
  );
}

String _date(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

String _dateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_date(local)} · $hour:$minute $period';
}
