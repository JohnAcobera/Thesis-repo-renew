import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../services/handout_pdf_exporter.dart';
import '../services/handout_service.dart';

class ContextContentScreen extends StatefulWidget {
  const ContextContentScreen({this.generator, this.pdfExporter, super.key});

  final HandoutGenerator? generator;
  final HandoutPdfExporter? pdfExporter;

  @override
  State<ContextContentScreen> createState() => _ContextContentScreenState();
}

class _ContextContentScreenState extends State<ContextContentScreen> {
  static const _palette = <(String, Color)>[
    ('Deep brown', Color(0xFF3B2419)),
    ('Charcoal', Color(0xFF343A40)),
    ('Blue', Color(0xFF2764AE)),
    ('Teal', Color(0xFF147D75)),
    ('Green', Color(0xFF388343)),
    ('Purple', Color(0xFF7650A8)),
    ('Red', Color(0xFFB54040)),
    ('Orange', Color(0xFFF4773C)),
  ];

  final _contextController = TextEditingController();
  Color _titleColor = const Color(0xFF3B2419);
  Color _termsColor = const Color(0xFF2764AE);
  Color _definitionsColor = const Color(0xFF725F53);
  StudyHandout? _handout;
  bool _isGenerating = false;
  bool _isExporting = false;

  late final HandoutGenerator _generator = widget.generator ?? HandoutService();
  late final HandoutPdfExporter _pdfExporter =
      widget.pdfExporter ?? PrintingHandoutPdfExporter();

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _chooseColor({
    required String label,
    required Color selectedColor,
    required ValueChanged<Color> onSelected,
  }) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, color) in _palette)
              Tooltip(
                message: name,
                child: Semantics(
                  button: true,
                  selected: color == selectedColor,
                  label: '$name color',
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(color),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                        backgroundColor: color,
                        radius: 17,
                        child: color == selectedColor
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (color != null && mounted) onSelected(color);
  }

  Future<void> _generateHandout() async {
    if (_isGenerating) return;
    final contextText = _contextController.text.trim();
    if (contextText.isEmpty) {
      _showMessage('Describe what you want to learn about.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _handout = null;
    });
    try {
      final handout = await _generator.generate(
        context: contextText,
        style: HandoutStyle(
          titleColor: _titleColor,
          termsColor: _termsColor,
          definitionsColor: _definitionsColor,
        ),
      );
      if (mounted) setState(() => _handout = handout);
    } on HandoutServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception catch (error) {
      if (mounted) _showMessage('Content generation failed: $error');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportPdf() async {
    final handout = _handout;
    if (handout == null || _isExporting) return;

    setState(() => _isExporting = true);
    try {
      await _pdfExporter.export(handout);
    } on HandoutPdfExportException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception catch (error) {
      if (mounted) _showMessage('PDF export failed: $error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateStyle({
    Color? titleColor,
    Color? termsColor,
    Color? definitionsColor,
  }) {
    setState(() {
      _titleColor = titleColor ?? _titleColor;
      _termsColor = termsColor ?? _termsColor;
      _definitionsColor = definitionsColor ?? _definitionsColor;
      final handout = _handout;
      if (handout != null) {
        _handout = handout.copyWith(
          style: HandoutStyle(
            titleColor: _titleColor,
            termsColor: _termsColor,
            definitionsColor: _definitionsColor,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Generate study content')),
    body: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SizedBox(
          width: constraints.maxWidth.clamp(0.0, 760.0).toDouble(),
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start with an idea',
                  style: TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Describe what you want to learn about. The connected '
                  'generation service will use this context to create structured '
                  'terms and definitions.',
                  style: TextStyle(color: Color(0xFF725F53), height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _contextController,
                  minLines: 4,
                  maxLines: 6,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final value = _limitToServiceLength(newValue.text);
                      if (value == newValue.text) return newValue;
                      final cursor = newValue.selection.extentOffset
                          .clamp(0, value.length)
                          .toInt();
                      return newValue.copyWith(
                        text: value,
                        selection: TextSelection.collapsed(offset: cursor),
                        composing: TextRange.empty,
                      );
                    }),
                  ],
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Your context',
                    hintText:
                        'For example: Explain the water cycle for beginners',
                    alignLabelWithHint: true,
                    counterText: '${_contextController.text.length}/200',
                    filled: true,
                    fillColor: const Color(0xFFFFF8F1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ColorSettingRow(
                  label: 'Title',
                  color: _titleColor,
                  onTap: () => _chooseColor(
                    label: 'Title',
                    selectedColor: _titleColor,
                    onSelected: (color) => _updateStyle(titleColor: color),
                  ),
                ),
                _ColorSettingRow(
                  label: 'Terms',
                  color: _termsColor,
                  onTap: () => _chooseColor(
                    label: 'Terms',
                    selectedColor: _termsColor,
                    onSelected: (color) => _updateStyle(termsColor: color),
                  ),
                ),
                _ColorSettingRow(
                  label: 'Definitions',
                  color: _definitionsColor,
                  onTap: () => _chooseColor(
                    label: 'Definitions',
                    selectedColor: _definitionsColor,
                    onSelected: (color) =>
                        _updateStyle(definitionsColor: color),
                  ),
                ),
                const SizedBox(height: 12),
                if (_handout == null)
                  Card(
                    color: const Color(0xFFFFF8F1),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview',
                            style: TextStyle(
                              color: _titleColor,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Example term',
                            style: TextStyle(
                              color: _termsColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A sample definition will appear here.',
                            style: TextStyle(color: _definitionsColor),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * 0.38)
                        .clamp(160.0, 360.0)
                        .toDouble(),
                    child: SingleChildScrollView(
                      key: const ValueKey('generated-handout-scroll'),
                      child: _GeneratedHandoutPreview(handout: _handout!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : _generateHandout,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _isGenerating
                          ? 'Generating handout...'
                          : 'Generate content',
                    ),
                  ),
                ),
                if (_handout != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportPdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _isExporting ? 'Preparing PDF...' : 'Download PDF',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _limitToServiceLength(String value) {
  var codeUnits = 0;
  var endOffset = 0;
  for (final rune in value.runes) {
    final runeLength = rune > 0xFFFF ? 2 : 1;
    if (codeUnits + runeLength > 200) break;
    codeUnits += runeLength;
    endOffset += runeLength;
  }
  return value.substring(0, endOffset);
}

class _GeneratedHandoutPreview extends StatelessWidget {
  const _GeneratedHandoutPreview({required this.handout});

  final StudyHandout handout;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF8F1),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            handout.title,
            style: TextStyle(
              color: handout.style.titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(handout.summary),
          for (final section in handout.sections) ...[
            const SizedBox(height: 18),
            Text(
              section.heading,
              style: TextStyle(
                color: handout.style.titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (section.overview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(section.overview),
            ],
            for (final subsection in section.subsections) ...[
              const SizedBox(height: 10),
              Text(
                subsection.heading,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (subsection.explanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subsection.explanation),
              ],
              for (var index = 0; index < subsection.items.length; index++)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          subsection.style == HandoutListStyle.numbered
                              ? '${index + 1}.'
                              : '•',
                        ),
                      ),
                      Expanded(child: Text(subsection.items[index])),
                    ],
                  ),
                ),
            ],
          ],
          const SizedBox(height: 18),
          Text(
            'Key terms',
            style: TextStyle(
              color: handout.style.titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final term in handout.terms) ...[
            const SizedBox(height: 10),
            Text(
              term.term,
              style: TextStyle(
                color: handout.style.termsColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              term.definition,
              style: TextStyle(color: handout.style.definitionsColor),
            ),
          ],
          if (handout.keyTakeaways.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Key takeaways',
              style: TextStyle(
                color: handout.style.titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final takeaway in handout.keyTakeaways)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 22, child: Text('•')),
                    Expanded(child: Text(takeaway)),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _ColorSettingRow extends StatelessWidget {
  const _ColorSettingRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$label text color',
            style: const TextStyle(
              color: Color(0xFF3B2419),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(Icons.palette_outlined, color: color),
          label: const Text('Palette'),
        ),
      ],
    ),
  );
}
