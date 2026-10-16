import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'profile_screen.dart';
import 'quiz_screen.dart';
import '../services/quiz_service.dart';
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
    super.key,
  });

  final String username;
  final String email;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  PlatformFile? _selectedFile;
  final Set<QuestionType> _selectedTypes = {QuestionType.multipleChoice};
  int _selectedItemCount = 10;
  bool _isGenerating = false;
  String? _generationStatus;

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
        final file = result.files.first;
        if (file.size > 3 * 1024 * 1024) {
          _showMessage('Choose a file that is 3 MB or smaller.');
          return;
        }
        if (mounted) setState(() => _selectedFile = file);
      }
    } on Exception catch (e) {
      if (mounted) {
        _showMessage('Failed to pick file: $e', isError: true);
      }
    }
  }

  void _clearFile() {
    setState(() => _selectedFile = null);
  }

  Future<void> _generate() async {
    if (_selectedFile == null) return;
    if (_selectedTypes.isEmpty) return;

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
            'Generating $_selectedItemCount questions. This may take up to a minute...',
      );
      final questions = await QuizService().generateQuiz(
        questionCount: _selectedItemCount,
        fileName: file.name,
        sourceText: sourceText,
      );
      if (!mounted) return;
      setState(() => _isGenerating = false);

      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => QuizScreen(
            username: widget.username,
            email: widget.email,
            role: widget.role,
            createdAt: widget.createdAt,
            onMenuSelected: widget.onMenuSelected,
            title: _quizTitle(file.name),
            sourceFile: file.name,
            questions: questions,
          ),
        ),
      );
      if (completed == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on QuizServiceException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Quiz generation failed: $error', isError: true);
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

  String _quizTitle(String fileName) {
    final extensionIndex = fileName.lastIndexOf('.');
    return extensionIndex > 0
        ? fileName.substring(0, extensionIndex)
        : fileName;
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
      title: 'Create a Quiz',
      username: widget.username,
      email: widget.email,
      role: _displayRole(widget.role),
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
        }
      },
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _FilePickerPanel(
                    selectedFile: _selectedFile,
                    onPick: _pickFile,
                    onClear: _clearFile,
                  ),
                  const SizedBox(height: 16),
                  _QuestionTypesPanel(
                    selectedTypes: _selectedTypes,
                    onChanged: (type, selected) {
                      setState(() {
                        if (selected) {
                          _selectedTypes.add(type);
                        } else {
                          _selectedTypes.remove(type);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _ItemCountPanel(
                    selectedCount: _selectedItemCount,
                    onChanged: (count) =>
                        setState(() => _selectedItemCount = count),
                  ),
                  const SizedBox(height: 24),
                  _GenerateButton(
                    onPressed: _generate,
                    isLoading: _isGenerating,
                    isEnabled:
                        _selectedFile != null && _selectedTypes.isNotEmpty,
                  ),
                  if (_isGenerating && _generationStatus != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _subtle,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _generationStatus!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _subtle,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
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
          'Upload your notes and generate a practice quiz',
          style: TextStyle(
            color: _heading,
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a file, choose the number of questions, and take your quiz.',
          style: TextStyle(fontSize: 16, height: 1.5, color: _subtle),
        ),
      ],
    );
  }
}

class _FilePickerPanel extends StatelessWidget {
  const _FilePickerPanel({
    required this.selectedFile,
    required this.onPick,
    required this.onClear,
  });

  final PlatformFile? selectedFile;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.upload_file_outlined,
      title: 'Source File',
      description: 'Upload a PDF, Word (DOCX), or text file',
      child: selectedFile == null ? _buildDropZone() : _buildFileInfo(),
    );
  }

  Widget _buildDropZone() {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: _inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
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
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Drag & drop a file here, or click to browse',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Supported: PDF, DOCX, TXT (max 3 MB)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _subtle),
            ),
          ],
        ),
      ),
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

class _QuestionTypesPanel extends StatelessWidget {
  const _QuestionTypesPanel({
    required this.selectedTypes,
    required this.onChanged,
  });

  final Set<QuestionType> selectedTypes;
  final void Function(QuestionType, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.quiz_outlined,
      title: 'Question Types',
      description: 'Choose the multiple-choice format for your quiz',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: QuestionType.values.map((type) {
          final isSelected = selectedTypes.contains(type);
          return _QuestionTypeChip(
            type: type,
            isSelected: isSelected,
            onTap: () => onChanged(type, !isSelected),
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

  final QuestionType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              type.label,
              style: TextStyle(
                color: isSelected ? Colors.white : _heading,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum QuestionType {
  multipleChoice('Multiple Choice', Icons.format_list_numbered_rounded);

  const QuestionType(this.label, this.icon);
  final String label;
  final IconData icon;
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
          if (constraints.maxWidth < 400) {
            return Column(
              children: items.map((count) => _buildRadioItem(count)).toList(),
            );
          }
          return Row(
            children: items
                .expand(
                  (count) => [
                    Expanded(child: _buildRadioItem(count)),
                    if (count != items.last) const SizedBox(width: 12),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildRadioItem(int count) {
    final isSelected = selectedCount == count;
    return InkWell(
      onTap: () => onChanged(count),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count == 1 ? 'Item' : 'Items',
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : _subtle,
                fontSize: 13,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
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
