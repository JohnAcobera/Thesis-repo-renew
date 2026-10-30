import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/learning_mode_service.dart';
import '../services/quiz_service.dart';
import '../services/student_notification_service.dart';
import '../widgets/app_glass_surface.dart';
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

enum _InventoryFilter { all, favorites, quiz, flashcards, matching }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    required this.user,
    required this.onMenuSelected,
    this.quizRepository,
    this.learningModeService,
    this.notificationRepository,
    super.key,
  });

  final UserModel user;
  final ValueChanged<StudentMenuItem> onMenuSelected;
  final QuizRepository? quizRepository;
  final LearningModeService? learningModeService;
  final StudentNotificationRepository? notificationRepository;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<_InventoryData> _inventory;
  _InventorySort _sort = _InventorySort.recent;
  _InventoryFilter _filter = _InventoryFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String>? _favoriteOverrides;
  final Set<String> _pendingFavorites = {};
  Set<String>? _archivedOverrides;
  bool _isShowingArchived = false;
  bool _isSavingArchive = false;

  String get _archivePreferenceKey =>
      'quizforge_inventory_archived_${widget.user.id}';

  @override
  void initState() {
    super.initState();
    _inventory = _loadInventory();
  }

  Future<_InventoryData> _loadInventory() async {
    final learningService = widget.learningModeService ?? LearningModeService();
    final results = await Future.wait<Object>([
      (widget.quizRepository ?? QuizService()).recentAttempts(),
      learningService.inventoryItems(),
      learningService.inventoryFavorites(),
      SharedPreferences.getInstance(),
    ]);
    final quizzes = results[0] as List<QuizActivity>;
    final learningItems = results[1] as List<LearningInventoryItem>;
    final preferences = results[3] as SharedPreferences;
    return _InventoryData(
      records: [
        for (final quiz in quizzes) _InventoryRecord.quiz(quiz),
        for (final item in learningItems) _InventoryRecord.learning(item),
      ],
      favoriteKeys: results[2] as Set<String>,
      archivedKeys:
          preferences.getStringList(_archivePreferenceKey)?.toSet() ?? const {},
    );
  }

  void _reload() {
    setState(() {
      _favoriteOverrides = null;
      _archivedOverrides = null;
      _inventory = _loadInventory();
    });
  }

  Future<void> _toggleFavorite(
    _InventoryRecord record,
    Set<String> favoriteKeys,
  ) async {
    final key = record.favoriteKey;
    final makeFavorite = !favoriteKeys.contains(key);
    setState(() => _pendingFavorites.add(key));
    try {
      await (widget.learningModeService ?? LearningModeService())
          .setInventoryFavorite(
            itemType: record.type,
            itemId: record.id,
            isFavorite: makeFavorite,
          );
      if (!mounted) return;
      setState(() {
        final updated = Set<String>.of(_favoriteOverrides ?? favoriteKeys);
        if (makeFavorite) {
          updated.add(key);
        } else {
          updated.remove(key);
        }
        _favoriteOverrides = updated;
        _pendingFavorites.remove(key);
      });
    } on LearningModeServiceException catch (error) {
      if (!mounted) return;
      setState(() => _pendingFavorites.remove(key));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception {
      if (!mounted) return;
      setState(() => _pendingFavorites.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update favorite. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      color: _inventoryPrimary,
      onRefresh: () async => _reload(),
      child: FutureBuilder<_InventoryData>(
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
              detail: 'Please try again in a moment.',
              action: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }

          final inventory = snapshot.data!;
          final favoriteKeys = _favoriteOverrides ?? inventory.favoriteKeys;
          final archivedKeys = _archivedOverrides ?? inventory.archivedKeys;
          final archivedCount = inventory.records
              .where((record) => archivedKeys.contains(record.favoriteKey))
              .length;
          final records = _filteredAndSorted(
            inventory.records,
            favoriteKeys: favoriteKeys,
            archivedKeys: archivedKeys,
          );
          final groups = _groupRecords(records);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
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
                        'Revisit generated quizzes, flashcards, and matching activities.',
                        style: TextStyle(color: _inventorySubtle, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _isShowingArchived = !_isShowingArchived,
                          ),
                          icon: Icon(
                            _isShowingArchived
                                ? Icons.inventory_2_outlined
                                : Icons.archive_outlined,
                          ),
                          label: Text(
                            _isShowingArchived
                                ? 'View inventory'
                                : 'View archive ($archivedCount)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InventoryControls(
                        filter: _filter,
                        sort: _sort,
                        searchController: _searchController,
                        onSearchChanged: (query) =>
                            setState(() => _searchQuery = query.trim()),
                        onFilterChanged: (filter) =>
                            setState(() => _filter = filter),
                        onSortChanged: (sort) => setState(() => _sort = sort),
                      ),
                      const SizedBox(height: 18),
                      if (records.isEmpty)
                        _InventoryMessage(
                          icon: _isShowingArchived
                              ? Icons.archive_outlined
                              : inventory.records.isEmpty
                              ? Icons.auto_stories_outlined
                              : Icons.search_off_rounded,
                          title: _isShowingArchived
                              ? 'Your archive is empty'
                              : inventory.records.isEmpty
                              ? 'Your inventory is ready'
                              : 'No activities found',
                          detail: _isShowingArchived
                              ? 'Items you archive will appear here. Your activity history remains unchanged.'
                              : inventory.records.isEmpty
                              ? 'Complete a generated activity and it will be saved here for your next study session.'
                              : 'Try a different title or activity filter.',
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
                        for (final type in const [
                          'quiz',
                          'flashcards',
                          'matching',
                        ])
                          if (groups[type]?.isNotEmpty ?? false) ...[
                            _InventoryGroupHeading(
                              title: switch (type) {
                                'quiz' => 'Quizzes',
                                'flashcards' => 'Flashcards',
                                _ => 'Matching activities',
                              },
                              count: groups[type]!.length,
                            ),
                            for (final record in groups[type]!) ...[
                              _InventoryTile(
                                record: record,
                                isFavorite: favoriteKeys.contains(
                                  record.favoriteKey,
                                ),
                                isFavoritePending: _pendingFavorites.contains(
                                  record.favoriteKey,
                                ),
                                onFavorite: () =>
                                    _toggleFavorite(record, favoriteKeys),
                                isArchived: _isShowingArchived,
                                isArchivePending: _isSavingArchive,
                                onArchive: () => _setArchived(
                                  record,
                                  archived: !_isShowingArchived,
                                ),
                                onTap: () => _openActivity(record),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 14),
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

  List<_InventoryRecord> _filteredAndSorted(
    List<_InventoryRecord> source, {
    required Set<String> favoriteKeys,
    required Set<String> archivedKeys,
  }) {
    final records = source.where((record) {
      if (archivedKeys.contains(record.favoriteKey) != _isShowingArchived) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !record.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return switch (_filter) {
        _InventoryFilter.all => true,
        _InventoryFilter.favorites => favoriteKeys.contains(record.favoriteKey),
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

  Future<void> _setArchived(
    _InventoryRecord record, {
    required bool archived,
  }) async {
    final key = record.favoriteKey;
    if (_isSavingArchive) return;
    setState(() => _isSavingArchive = true);
    try {
      final updated = Set<String>.of(_archivedOverrides ?? const {});
      if (_archivedOverrides == null) {
        final inventory = await _inventory;
        updated.addAll(inventory.archivedKeys);
      }
      if (archived) {
        updated.add(key);
      } else {
        updated.remove(key);
      }
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(
        _archivePreferenceKey,
        updated.toList(growable: false),
      );
      if (!saved) {
        if (mounted) {
          setState(() => _isSavingArchive = false);
          _showArchiveSaveFailure();
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _archivedOverrides = updated;
        _isSavingArchive = false;
      });
      if (archived) _showArchiveMessage();
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'learning inventory',
          context: ErrorDescription('while saving an archive change'),
        ),
      );
      if (!mounted) return;
      setState(() => _isSavingArchive = false);
      _showArchiveSaveFailure();
    }
  }

  void _showArchiveSaveFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not update the archive. Please try again.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showArchiveMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Item placed in the archive',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 310,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Map<String, List<_InventoryRecord>> _groupRecords(
    List<_InventoryRecord> records,
  ) {
    final groups = <String, List<_InventoryRecord>>{};
    for (final record in records) {
      groups.putIfAbsent(record.type, () => []).add(record);
    }
    return groups;
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
            notificationRepository: widget.notificationRepository,
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

  String get id => quiz?.id ?? learning!.id;
  String get favoriteKey => inventoryFavoriteKey(type, id);
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

class _InventoryData {
  const _InventoryData({
    required this.records,
    required this.favoriteKeys,
    required this.archivedKeys,
  });

  final List<_InventoryRecord> records;
  final Set<String> favoriteKeys;
  final Set<String> archivedKeys;
}

class _InventoryControls extends StatelessWidget {
  const _InventoryControls({
    required this.filter,
    required this.sort,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final _InventoryFilter filter;
  final _InventorySort sort;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_InventoryFilter> onFilterChanged;
  final ValueChanged<_InventorySort> onSortChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search activity titles',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    onSearchChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _InventoryFilter.values
              .map((value) {
                final selected = filter == value;
                final label = switch (value) {
                  _InventoryFilter.all => 'All',
                  _InventoryFilter.favorites => 'Favorites',
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
          width: 310,
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
  const _InventoryTile({
    required this.record,
    required this.isFavorite,
    required this.isFavoritePending,
    required this.onFavorite,
    required this.isArchived,
    required this.isArchivePending,
    required this.onArchive,
    required this.onTap,
  });

  final _InventoryRecord record;
  final bool isFavorite;
  final bool isFavoritePending;
  final VoidCallback onFavorite;
  final bool isArchived;
  final bool isArchivePending;
  final VoidCallback onArchive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 18,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              IconButton(
                tooltip: isArchived ? 'Restore to inventory' : 'Archive item',
                onPressed: isArchivePending ? null : onArchive,
                icon: isArchivePending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        color: _inventorySubtle,
                      ),
              ),
              IconButton(
                tooltip: isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: isFavoritePending ? null : onFavorite,
                icon: isFavoritePending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? _inventoryPrimary
                            : _inventorySubtle,
                      ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _inventorySubtle),
            ],
          ),
        ),
      ),
    ),
  );

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _InventoryGroupHeading extends StatelessWidget {
  const _InventoryGroupHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _inventoryHeading,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: _inventoryFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _inventoryPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
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
