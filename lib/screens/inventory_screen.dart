import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/learning_mode_service.dart';
import '../services/quiz_service.dart';
import '../widgets/student_side_menu.dart';
import 'quiz_screen.dart';
import 'study_activity_screens.dart';

const _inventoryPrimary = Color(0xFFFF7434);
const _inventoryFill = Color(0xFFFFF1DF);
const _inventoryBorder = Color(0xFFE8D7C2);
const _inventoryHeading = Color(0xFF3B2419);
const _inventorySubtle = Color(0xFF725F53);

enum _InventorySort { recent, score, attempts, name }

extension on _InventorySort {
  String get label => switch (this) {
    _InventorySort.recent => 'Most recent',
    _InventorySort.score => 'Highest score',
    _InventorySort.attempts => 'Most attempts',
    _InventorySort.name => 'Name A-Z',
  };
}

enum _InventoryFilter { all, quiz, flashcards, matching }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    required this.user,
    required this.onMenuSelected,
    super.key,
  });

  final UserModel user;
  final ValueChanged<StudentMenuItem> onMenuSelected;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<_InventoryRecord>> _inventory;
  _InventorySort _sort = _InventorySort.recent;
  _InventoryFilter _filter = _InventoryFilter.all;

  @override
  void initState() {
    super.initState();
    _inventory = _loadInventory();
  }

  Future<List<_InventoryRecord>> _loadInventory() async {
    final results = await Future.wait<Object>([
      QuizService().recentAttempts(),
      LearningModeService().inventoryItems(),
    ]);
    final quizzes = results[0] as List<QuizActivity>;
    final learningItems = results[1] as List<LearningInventoryItem>;
    return [
      for (final quiz in quizzes)
        if (quiz.classroomActivityId == null) _InventoryRecord.quiz(quiz),
      for (final item in learningItems) _InventoryRecord.learning(item),
    ];
  }

  void _reload() {
    setState(() => _inventory = _loadInventory());
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      color: _inventoryPrimary,
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<_InventoryRecord>>(
        future: _inventory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _inventoryPrimary),
            );
          }
          if (snapshot.hasError) {
            return _InventoryMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your inventory',
              detail: '${snapshot.error}',
              action: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }

          final records = _filteredAndSorted(snapshot.data ?? const []);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your learning library',
                        style: TextStyle(
                          color: _inventoryHeading,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Revisit generated quizzes, flashcards, and matching games.',
                        style: TextStyle(color: _inventorySubtle, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      _InventoryControls(
                        filter: _filter,
                        sort: _sort,
                        onFilterChanged: (filter) =>
                            setState(() => _filter = filter),
                        onSortChanged: (sort) => setState(() => _sort = sort),
                      ),
                      const SizedBox(height: 18),
                      if (records.isEmpty)
                        const _InventoryMessage(
                          icon: Icons.auto_stories_outlined,
                          title: 'Your inventory is ready',
                          detail:
                              'Complete a generated activity and it will be saved here for your next study session.',
                        )
                      else ...[
                        Text(
                          '${records.length} ${records.length == 1 ? 'activity' : 'activities'}',
                          style: const TextStyle(
                            color: _inventorySubtle,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final record in records) ...[
                          _InventoryTile(
                            record: record,
                            onTap: () => _openActivity(record),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  List<_InventoryRecord> _filteredAndSorted(List<_InventoryRecord> source) {
    final records = source.where((record) {
      return switch (_filter) {
        _InventoryFilter.all => true,
        _InventoryFilter.quiz => record.isQuiz,
        _InventoryFilter.flashcards => record.type == 'flashcards',
        _InventoryFilter.matching => record.type == 'matching',
      };
    }).toList();
    records.sort((first, second) {
      return switch (_sort) {
        _InventorySort.recent => second.lastActivity.compareTo(
          first.lastActivity,
        ),
        _InventorySort.score => second.bestScore.compareTo(first.bestScore),
        _InventorySort.attempts => second.attemptCount.compareTo(
          first.attemptCount,
        ),
        _InventorySort.name => first.title.toLowerCase().compareTo(
          second.title.toLowerCase(),
        ),
      };
    });
    return records;
  }

  Future<void> _openActivity(_InventoryRecord record) async {
    final completed = await switch (record.type) {
      'quiz' => Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => QuizScreen(
            username: widget.user.fullName,
            email: widget.user.email,
            role: widget.user.role,
            createdAt: widget.user.createdAt,
            onMenuSelected: widget.onMenuSelected,
            title: record.quiz!.title,
            sourceFile: record.quiz!.sourceFile,
            questions: record.quiz!.questions,
            quizId: record.quiz!.id,
            previousAttempts: record.quiz!.attempts,
          ),
        ),
      ),
      'flashcards' => Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => FlashcardsScreen(
            activityId: record.learning!.id,
            username: widget.user.fullName,
            email: widget.user.email,
            role: widget.user.role,
            createdAt: widget.user.createdAt,
            onMenuSelected: widget.onMenuSelected,
            title: record.learning!.title,
            sourceFile: record.learning!.sourceFile,
            cards: record.learning!.flashcards,
          ),
        ),
      ),
      _ => Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => MatchingScreen(
            activityId: record.learning!.id,
            username: widget.user.fullName,
            email: widget.user.email,
            role: widget.user.role,
            createdAt: widget.user.createdAt,
            onMenuSelected: widget.onMenuSelected,
            title: record.learning!.title,
            sourceFile: record.learning!.sourceFile,
            pairs: record.learning!.matchingPairs,
          ),
        ),
      ),
    };
    if (completed == true && mounted) _reload();
  }
}

class _InventoryRecord {
  _InventoryRecord.quiz(this.quiz) : learning = null, type = 'quiz';

  _InventoryRecord.learning(LearningInventoryItem item)
    : quiz = null,
      learning = item,
      type = item.type == LearningActivityType.flashcards
          ? 'flashcards'
          : 'matching';

  final String type;
  final QuizActivity? quiz;
  final LearningInventoryItem? learning;

  bool get isQuiz => type == 'quiz';
  String get title => quiz?.title ?? learning!.title;
  String get sourceFile => quiz?.sourceFile ?? learning!.sourceFile;
  DateTime get lastActivity =>
      quiz?.latestAttempt?.createdAt ?? learning!.lastActivity;
  int get attemptCount => quiz?.attempts.length ?? learning!.attemptCount;
  int get bestScore => quiz?.highestPercentage ?? learning!.bestScore.round();
  int get itemCount => quiz?.totalQuestions ?? learning!.itemCount;

  IconData get icon => switch (type) {
    'quiz' => Icons.quiz_outlined,
    'flashcards' => Icons.style_outlined,
    _ => Icons.extension_outlined,
  };

  String get label => switch (type) {
    'quiz' => 'Quiz',
    'flashcards' => 'Flashcards',
    _ => 'Matching',
  };
}

class _InventoryControls extends StatelessWidget {
  const _InventoryControls({
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final _InventoryFilter filter;
  final _InventorySort sort;
  final ValueChanged<_InventoryFilter> onFilterChanged;
  final ValueChanged<_InventorySort> onSortChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _InventoryFilter.values
              .map((value) {
                final selected = filter == value;
                final label = switch (value) {
                  _InventoryFilter.all => 'All',
                  _InventoryFilter.quiz => 'Quizzes',
                  _InventoryFilter.flashcards => 'Flashcards',
                  _InventoryFilter.matching => 'Matching',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => onFilterChanged(value),
                    selectedColor: _inventoryPrimary,
                    backgroundColor: _inventoryFill,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _inventoryHeading,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected ? _inventoryPrimary : _inventoryBorder,
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 210,
          child: DropdownButtonFormField<_InventorySort>(
            initialValue: sort,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort_rounded),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: _InventorySort.values
                .map(
                  (value) => DropdownMenuItem<_InventorySort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          ),
        ),
      ),
    ],
  );
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.record, required this.onTap});

  final _InventoryRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _inventoryBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _inventoryFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(record.icon, color: _inventoryPrimary),
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
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _inventoryHeading,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeBadge(label: record.label),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${record.itemCount} items · ${record.sourceFile}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _inventorySubtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(record.lastActivity)} · ${record.attemptCount} ${record.attemptCount == 1 ? 'attempt' : 'attempts'} · ${record.bestScore}% best',
                    style: const TextStyle(
                      color: _inventoryPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _inventorySubtle),
          ],
        ),
      ),
    ),
  );

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _inventoryFill,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: _inventoryPrimary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InventoryMessage extends StatelessWidget {
  const _InventoryMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _inventoryPrimary, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _inventoryHeading,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _inventorySubtle, height: 1.45),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

String _displayRole(String role) => role.isEmpty
    ? role
    : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
