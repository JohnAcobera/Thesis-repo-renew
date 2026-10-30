import 'package:flutter/material.dart';

import '../models/learning_material_model.dart';
import '../services/instructor_learning_materials_service.dart';
import '../widgets/app_glass_surface.dart';

const _materialsPrimary = Color(0xFFFF7434);
const _materialsHeading = Color(0xFF3B2419);
const _materialsSubtle = Color(0xFF765C4F);
const _materialsBorder = Color(0xFFE8D7C2);
const _materialsMenuSurface = Color(0xFFFFFCF8);
const _materialsMenuSelection = Color(0xFFFFE9DA);
const _unfiledFolderFilter = '__unfiled__';

InputDecoration _materialsDropdownDecoration({
  String? labelText,
  IconData? prefixIcon,
  Widget? prefix,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  ),
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _materialsBorder),
  );
  return InputDecoration(
    labelText: labelText,
    prefixIcon: prefix ?? (prefixIcon == null ? null : Icon(prefixIcon)),
    filled: true,
    fillColor: _materialsMenuSurface,
    contentPadding: contentPadding,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: _materialsPrimary, width: 1.5),
    ),
  );
}

enum _MaterialSort { recent, name, questionCount }

extension on _MaterialSort {
  String get label => switch (this) {
    _MaterialSort.recent => 'Most recent',
    _MaterialSort.name => 'Name A–Z',
    _MaterialSort.questionCount => 'Question count',
  };
}

class LearningMaterialsScreen extends StatefulWidget {
  const LearningMaterialsScreen({this.materialsRepository, super.key});

  final InstructorLearningMaterialsRepository? materialsRepository;

  @override
  State<LearningMaterialsScreen> createState() =>
      _LearningMaterialsScreenState();
}

class _LearningMaterialsScreenState extends State<LearningMaterialsScreen> {
  late final InstructorLearningMaterialsRepository _repository =
      widget.materialsRepository ?? InstructorLearningMaterialsService();
  late Future<_LearningMaterialsData> _materials;
  String? _deletingMaterialId;
  String? _movingMaterialId;
  String? _selectedFolderFilter;
  _MaterialSort _sort = _MaterialSort.recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _materials = _loadData();
  }

  Future<_LearningMaterialsData> _loadData() async {
    final result = await Future.wait<Object>([
      _repository.listMaterials(),
      _repository.listFolders(),
    ]);
    return _LearningMaterialsData(
      materials: result[0] as List<LearningMaterialModel>,
      folders: result[1] as List<LearningMaterialFolder>,
    );
  }

  Future<void> _createFolder() async {
    var folderName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Create folder',
          style: TextStyle(
            color: _materialsHeading,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g., Biology review',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => folderName = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, folderName.trim()),
            style: FilledButton.styleFrom(backgroundColor: _materialsPrimary),
            child: const Text('Create folder'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final folder = await _repository.createFolder(name);
      if (!mounted) return;
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder “${folder.name}” created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on InstructorLearningMaterialsException catch (error) {
      if (mounted) _showError(error.message);
    } on Exception catch (error) {
      if (mounted) _showError('The folder could not be created: $error');
    }
  }

  Future<void> _moveMaterial(
    LearningMaterialModel material,
    String? folderId,
  ) async {
    if (material.folderId == folderId) return;
    setState(() => _movingMaterialId = material.id);
    try {
      await _repository.assignMaterialToFolder(
        quizId: material.id,
        folderId: folderId,
      );
      if (mounted) setState(_load);
    } on InstructorLearningMaterialsException catch (error) {
      if (mounted) _showError(error.message);
    } on Exception catch (error) {
      if (mounted) _showError('The quiz could not be moved: $error');
    } finally {
      if (mounted) setState(() => _movingMaterialId = null);
    }
  }

  List<LearningMaterialModel> _filterAndSortMaterials(
    List<LearningMaterialModel> materials,
  ) {
    final filtered = materials.where((material) {
      if (_selectedFolderFilter == null) return true;
      if (_selectedFolderFilter == _unfiledFolderFilter) {
        return material.folderId == null;
      }
      return material.folderId == _selectedFolderFilter;
    }).toList();
    filtered.sort(
      (first, second) => switch (_sort) {
        _MaterialSort.recent => second.createdAt.compareTo(first.createdAt),
        _MaterialSort.name => first.title.toLowerCase().compareTo(
          second.title.toLowerCase(),
        ),
        _MaterialSort.questionCount => second.questionCount.compareTo(
          first.questionCount,
        ),
      },
    );
    return filtered;
  }

  Map<String, List<LearningMaterialModel>> _groupMaterials(
    List<LearningMaterialModel> materials,
    List<LearningMaterialFolder> folders,
  ) {
    final names = {for (final folder in folders) folder.id: folder.name};
    final groups = <String, List<LearningMaterialModel>>{};
    for (final material in materials) {
      final group = material.folderId == null
          ? 'Unfiled'
          : names[material.folderId] ?? 'Unfiled';
      groups.putIfAbsent(group, () => []).add(material);
    }
    return groups;
  }

  Future<void> _deleteMaterial(LearningMaterialModel material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFB42318),
          size: 32,
        ),
        title: const Text(
          'Delete saved quiz?',
          style: TextStyle(
            color: _materialsHeading,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '“${material.title}” will be permanently removed from your '
          'Learning Materials. This cannot be undone.',
          style: const TextStyle(color: _materialsSubtle, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text('Delete quiz'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingMaterialId = material.id);
    try {
      await _repository.deleteMaterial(material.id);
      if (!mounted) return;
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on InstructorLearningMaterialsException catch (error) {
      if (mounted) _showError(error.message);
    } on Exception catch (error) {
      if (mounted) _showError('The quiz could not be deleted: $error');
    } finally {
      if (mounted) setState(() => _deletingMaterialId = null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const title = Text(
                  'Learning Materials',
                  style: TextStyle(
                    color: _materialsHeading,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(_load),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _materialsPrimary,
                        side: const BorderSide(color: _materialsBorder),
                      ),
                    ),
                  ],
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Expanded(child: title),
                    actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Your saved quizzes, ready to organize and reuse.',
              style: TextStyle(color: _materialsSubtle, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FutureBuilder<_LearningMaterialsData>(
              future: _materials,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _materialsPrimary,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  final message =
                      snapshot.error is InstructorLearningMaterialsException
                      ? (snapshot.error!
                                as InstructorLearningMaterialsException)
                            .message
                      : 'Learning materials could not be loaded.';
                  return _MaterialsMessage(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to load learning materials',
                    message: message,
                    action: TextButton.icon(
                      onPressed: () => setState(_load),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  );
                }

                final data = snapshot.data!;
                final materials = data.materials;
                final filtered = _filterAndSortMaterials(materials);
                final groups = _groupMaterials(filtered, data.folders);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LibraryControls(
                      folders: data.folders,
                      selectedFolderId: _selectedFolderFilter,
                      sort: _sort,
                      onCreateFolder: _createFolder,
                      onFolderChanged: (folderId) =>
                          setState(() => _selectedFolderFilter = folderId),
                      onSortChanged: (sort) => setState(() => _sort = sort),
                    ),
                    const SizedBox(height: 16),
                    if (materials.isEmpty)
                      const _MaterialsMessage(
                        icon: Icons.menu_book_outlined,
                        title: 'Your library is ready',
                        message:
                            'Quizzes you save after generating them will appear '
                            'here. Create folders now to keep your library organized.',
                      )
                    else if (filtered.isEmpty)
                      const _MaterialsMessage(
                        icon: Icons.filter_list_off_rounded,
                        title: 'No quizzes in this view',
                        message:
                            'Choose another folder or change the sort and filter settings.',
                      )
                    else
                      for (final group in groups.entries) ...[
                        _FolderGroupHeading(
                          title: group.key,
                          count: group.value.length,
                        ),
                        const SizedBox(height: 10),
                        for (final material in group.value) ...[
                          _LearningMaterialCard(
                            material: material,
                            folders: data.folders,
                            isDeleting: _deletingMaterialId == material.id,
                            isMoving: _movingMaterialId == material.id,
                            anyActionInProgress:
                                _deletingMaterialId != null ||
                                _movingMaterialId != null,
                            onFolderChanged: (folderId) =>
                                _moveMaterial(material, folderId),
                            onDelete: () => _deleteMaterial(material),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _LearningMaterialsData {
  const _LearningMaterialsData({
    required this.materials,
    required this.folders,
  });

  final List<LearningMaterialModel> materials;
  final List<LearningMaterialFolder> folders;
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.folders,
    required this.selectedFolderId,
    required this.sort,
    required this.onCreateFolder,
    required this.onFolderChanged,
    required this.onSortChanged,
  });

  final List<LearningMaterialFolder> folders;
  final String? selectedFolderId;
  final _MaterialSort sort;
  final VoidCallback onCreateFolder;
  final ValueChanged<String?> onFolderChanged;
  final ValueChanged<_MaterialSort> onSortChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 230,
        child: Theme(
          data: Theme.of(context).copyWith(focusColor: _materialsMenuSelection),
          child: DropdownButtonFormField<String?>(
            initialValue: selectedFolderId,
            isExpanded: true,
            dropdownColor: _materialsMenuSurface,
            borderRadius: BorderRadius.circular(14),
            elevation: 10,
            menuMaxHeight: 360,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            style: const TextStyle(color: _materialsHeading, fontSize: 14),
            decoration: _materialsDropdownDecoration(
              labelText: 'Show folder',
              prefixIcon: Icons.folder_open_outlined,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All quizzes'),
              ),
              const DropdownMenuItem<String?>(
                value: _unfiledFolderFilter,
                child: Text('Unfiled'),
              ),
              for (final folder in folders)
                DropdownMenuItem<String?>(
                  value: folder.id,
                  child: Text(folder.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onFolderChanged,
          ),
        ),
      ),
      SizedBox(
        width: 210,
        child: Theme(
          data: Theme.of(context).copyWith(focusColor: _materialsMenuSelection),
          child: DropdownButtonFormField<_MaterialSort>(
            initialValue: sort,
            isExpanded: true,
            dropdownColor: _materialsMenuSurface,
            borderRadius: BorderRadius.circular(14),
            elevation: 10,
            menuMaxHeight: 360,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            style: const TextStyle(color: _materialsHeading, fontSize: 14),
            decoration: _materialsDropdownDecoration(
              labelText: 'Sort by',
              prefixIcon: Icons.sort_rounded,
            ),
            items: _MaterialSort.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: onCreateFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New folder'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _materialsPrimary,
          side: const BorderSide(color: _materialsBorder),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    ],
  );
}

class _FolderGroupHeading extends StatelessWidget {
  const _FolderGroupHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.folder_outlined, color: _materialsPrimary, size: 19),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _materialsHeading,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5D5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: _materialsHeading,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _LearningMaterialCard extends StatelessWidget {
  const _LearningMaterialCard({
    required this.material,
    required this.folders,
    required this.isDeleting,
    required this.isMoving,
    required this.anyActionInProgress,
    required this.onFolderChanged,
    required this.onDelete,
  });

  final LearningMaterialModel material;
  final List<LearningMaterialFolder> folders;
  final bool isDeleting;
  final bool isMoving;
  final bool anyActionInProgress;
  final ValueChanged<String?> onFolderChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 18,
    padding: const EdgeInsets.all(18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: anyActionInProgress ? null : onDelete,
              icon: isDeleting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
                side: const BorderSide(color: Color(0xFFE7B8B4)),
              ),
            ),
          ],
        );

        final details = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5D5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.quiz_outlined, color: _materialsPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: const TextStyle(
                      color: _materialsHeading,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    material.sourceFile,
                    style: const TextStyle(
                      color: _materialsSubtle,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MaterialTag(
                        icon: Icons.help_outline_rounded,
                        label:
                            '${material.questionCount} '
                            '${material.questionCount == 1 ? 'question' : 'questions'}',
                      ),
                      _MaterialTag(
                        icon: Icons.calendar_today_outlined,
                        label: MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(material.createdAt.toLocal()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(focusColor: _materialsMenuSelection),
                    child: DropdownButtonFormField<String?>(
                      initialValue: material.folderId,
                      isExpanded: true,
                      dropdownColor: _materialsMenuSurface,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 10,
                      menuMaxHeight: 320,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      style: const TextStyle(
                        color: _materialsHeading,
                        fontSize: 14,
                      ),
                      decoration: _materialsDropdownDecoration(
                        labelText: 'Folder',
                        prefix: isMoving
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(Icons.folder_outlined),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unfiled'),
                        ),
                        for (final folder in folders)
                          DropdownMenuItem<String?>(
                            value: folder.id,
                            child: Text(
                              folder.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: anyActionInProgress ? null : onFolderChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 16), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: details),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    ),
  );
}

class _MaterialTag extends StatelessWidget {
  const _MaterialTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E9),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFF0DFCF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _materialsPrimary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: _materialsHeading,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _MaterialsMessage extends StatelessWidget {
  const _MaterialsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _materialsBorder),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFFC49A7E), size: 38),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _materialsHeading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _materialsSubtle, height: 1.4),
        ),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ],
    ),
  );
}
