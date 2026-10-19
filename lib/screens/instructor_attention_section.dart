import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/instructor_report.dart';
import '../services/instructor_reports_service.dart';

const _attentionAccent = Color(0xFFF4773C);
const _attentionInk = Color(0xFF3B2419);
const _attentionMuted = Color(0xFF765C4F);
const _attentionBorder = Color(0xFFE8D7C2);
const _lowScoreThreshold = 60.0;

class InstructorAttentionSection extends StatefulWidget {
  const InstructorAttentionSection({
    required this.reportsRepository,
    super.key,
  });

  final InstructorReportsRepository reportsRepository;

  @override
  State<InstructorAttentionSection> createState() =>
      _InstructorAttentionSectionState();
}

class _InstructorAttentionSectionState
    extends State<InstructorAttentionSection> {
  late Future<List<InstructorReportClassroom>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = widget.reportsRepository.loadReports();
  }

  void _reload() {
    setState(() {
      _reports = widget.reportsRepository.loadReports();
    });
  }

  List<_AttentionStudent> _studentsNeedingAttention(
    List<InstructorReportClassroom> reports,
  ) {
    final students = <int, _AttentionStudent>{};
    for (final classroom in reports) {
      for (final student in classroom.students) {
        if (student.role != 'student') continue;
        final details = students.putIfAbsent(
          student.id,
          () => _AttentionStudent(
            id: student.id,
            fullName: student.fullName,
            email: student.email,
          ),
        );
        final incompleteActivities = math.max(
          0,
          student.totalActivityCount - student.completedActivityCount,
        );
        final concerns = <String>[
          if (student.averageScore != null &&
              student.averageScore! < _lowScoreThreshold)
            'Low quiz average: ${student.averageScore!.round()}%',
          if (incompleteActivities > 0)
            student.completedActivityCount == 0
                ? 'No quiz attempts'
                : '$incompleteActivities of ${student.totalActivityCount} quizzes not completed',
        ];
        details.classrooms.add(
          _AttentionClassroom(
            id: classroom.id,
            name: classroom.name,
            subject: classroom.subject,
            averageScore: student.averageScore,
            concerns: concerns,
          ),
        );
      }
    }
    final flaggedStudents = students.values
        .where(
          (student) =>
              student.classrooms.any((room) => room.concerns.isNotEmpty),
        )
        .toList(growable: false);
    flaggedStudents.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return flaggedStudents;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _attentionBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A3B2419),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: FutureBuilder<List<InstructorReportClassroom>>(
      future: _reports,
      builder: (context, snapshot) {
        final attentionStudents = snapshot.hasData
            ? _studentsNeedingAttention(snapshot.data!)
            : const <_AttentionStudent>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9DA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent_outlined,
                    color: _attentionAccent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Students needing attention',
                        style: TextStyle(
                          color: _attentionInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Students with low quiz averages or incomplete quizzes.',
                        style: TextStyle(color: _attentionMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh student insights',
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  color: _attentionMuted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const _AttentionLoading()
            else if (snapshot.hasError)
              _AttentionError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (attentionStudents.isEmpty)
              const _AttentionEmpty()
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: _attentionAccent,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${attentionStudents.length} ${attentionStudents.length == 1 ? 'student needs' : 'students need'} follow-up',
                        style: const TextStyle(
                          color: _attentionInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (
                var index = 0;
                index < attentionStudents.length;
                index++
              ) ...[
                _AttentionStudentCard(student: attentionStudents[index]),
                if (index < attentionStudents.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    ),
  );
}

class _AttentionStudent {
  _AttentionStudent({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final int id;
  final String fullName;
  final String email;
  final List<_AttentionClassroom> classrooms = [];
}

class _AttentionClassroom {
  const _AttentionClassroom({
    required this.id,
    required this.name,
    required this.subject,
    required this.averageScore,
    required this.concerns,
  });

  final String id;
  final String name;
  final String subject;
  final double? averageScore;
  final List<String> concerns;
}

class _AttentionStudentCard extends StatelessWidget {
  const _AttentionStudentCard({required this.student});

  final _AttentionStudent student;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('attention-student-${student.id}'),
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _attentionBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFFE9DA),
              child: Text(
                student.fullName.trim().isEmpty
                    ? '?'
                    : student.fullName.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: _attentionAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: const TextStyle(
                      color: _attentionInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student.email,
                    style: const TextStyle(
                      color: _attentionMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final classroom in student.classrooms) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFF0E5D8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 15,
                      color: _attentionAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${classroom.name} · ${classroom.subject}',
                        key: ValueKey(
                          'attention-classroom-${student.id}-${classroom.id}',
                        ),
                        style: const TextStyle(
                          color: _attentionInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (classroom.averageScore != null)
                      Text(
                        '${classroom.averageScore!.round()}%',
                        style: TextStyle(
                          color: classroom.averageScore! < _lowScoreThreshold
                              ? const Color(0xFFB84735)
                              : _attentionMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: classroom.concerns.isEmpty
                      ? const [
                          _AttentionTag(label: 'On track', isNeutral: true),
                        ]
                      : classroom.concerns
                            .map((concern) => _AttentionTag(label: concern))
                            .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _AttentionTag extends StatelessWidget {
  const _AttentionTag({required this.label, this.isNeutral = false});

  final String label;
  final bool isNeutral;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isNeutral ? const Color(0xFFF2F0EA) : const Color(0xFFFFEFEC),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: isNeutral ? _attentionMuted : const Color(0xFF9E3C2E),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AttentionLoading extends StatelessWidget {
  const _AttentionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 30),
    child: Center(child: CircularProgressIndicator(color: _attentionAccent)),
  );
}

class _AttentionEmpty extends StatelessWidget {
  const _AttentionEmpty();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _attentionBorder),
    ),
    child: const Column(
      children: [
        Icon(Icons.task_alt_rounded, size: 28, color: Color(0xFF5C8A65)),
        SizedBox(height: 7),
        Text(
          'No students need follow-up right now',
          style: TextStyle(
            color: _attentionInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Students with low scores or incomplete quizzes will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _attentionMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _AttentionError extends StatelessWidget {
  const _AttentionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFEC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB84735)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Student insights could not be loaded. $message',
            style: const TextStyle(color: Color(0xFF87372C), fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
