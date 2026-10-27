import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/learning_mode_service.dart';
import '../widgets/student_side_menu.dart';
import 'profile_screen.dart';

const _studyPrimary = Color(0xFFFF7434);
const _studyFill = Color(0xFFFFF1DF);
const _studyBorder = Color(0xFFE8D7C2);
const _studyHeading = Color(0xFF3B2419);
const _studySubtle = Color(0xFF725F53);

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({
    required this.activityId,
    required this.username,
    required this.email,
    required this.title,
    required this.sourceFile,
    required this.cards,
    this.role = 'student',
    this.createdAt,
    this.onMenuSelected,
    this.learningModeService,
    this.isReviewRound = false,
    super.key,
  });

  final String activityId;
  final String username;
  final String email;
  final String title;
  final String sourceFile;
  final List<Flashcard> cards;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;
  final LearningModeService? learningModeService;
  final bool isReviewRound;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late final List<int> _queue = List<int>.generate(
    widget.cards.length,
    (index) => index,
  );
  final Set<int> _mastered = {};
  final Set<int> _reviewAgainCardIndexes = {};
  bool _isFlipped = false;
  bool _isHintVisible = false;
  bool _isFinished = false;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _saveError;

  Flashcard get _card => widget.cards[_queue.first];

  Future<void> _rateCard({required bool gotIt}) async {
    if (_isFinished) return;
    final cardIndex = _queue.removeAt(0);
    setState(() {
      if (gotIt) {
        _mastered.add(cardIndex);
      } else {
        _mastered.remove(cardIndex);
        if (!widget.isReviewRound) _reviewAgainCardIndexes.add(cardIndex);
        final requeueAt = math.min(2, _queue.length);
        _queue.insert(requeueAt, cardIndex);
      }
      _isFlipped = false;
      _isHintVisible = false;
    });

    if (_mastered.length == widget.cards.length) {
      setState(() => _isFinished = true);
      if (!widget.isReviewRound) await _saveResult();
    }
  }

  Future<void> _saveResult() async {
    if (_isSaving || _isSaved) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await (widget.learningModeService ?? LearningModeService()).saveAttempt(
        itemId: widget.activityId,
        score: _mastered.length,
        totalItems: widget.cards.length,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });
    } on LearningModeServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = error.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Your flashcard session could not be saved. Try again.';
      });
    }
  }

  void _returnToDashboard() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => StudentScaffold(
    title: _isFinished ? 'Flashcards complete' : 'Study flashcards',
    username: widget.username,
    email: widget.email,
    role: _displayRole(widget.role),
    onBack: () => Navigator.of(context).maybePop(_isSaved),
    onMenuSelected: (item) => _handleMenuSelection(
      context,
      item,
      username: widget.username,
      email: widget.email,
      role: widget.role,
      createdAt: widget.createdAt,
      onMenuSelected: widget.onMenuSelected,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _isFinished ? _buildResult() : _buildStudyCard(),
          ),
        ),
      ),
    ),
  );

  Widget _buildStudyCard() {
    final position = widget.cards.length - _queue.length + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudyHeading(
          eyebrow: widget.isReviewRound ? 'CARD REVIEW' : 'FLASHCARDS',
          title: widget.title,
          subtitle: '${widget.cards.length} cards · ${widget.sourceFile}',
        ),
        const SizedBox(height: 22),
        _ProgressSummary(
          label: 'Cards mastered',
          detail: '${_mastered.length} of ${widget.cards.length}',
          progress: _mastered.length / widget.cards.length,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CARD $position',
              style: const TextStyle(
                color: _studySubtle,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'Tap the card to flip',
              style: TextStyle(color: _studySubtle, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FlipCard(
          card: _card,
          flipped: _isFlipped,
          onFlip: () => setState(() => _isFlipped = !_isFlipped),
          hintVisible: _isHintVisible,
          onHintPressed: () => setState(() => _isHintVisible = true),
        ),
        const SizedBox(height: 20),
        if (_isFlipped)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rateCard(gotIt: false),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Review again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _studyHeading,
                    side: const BorderSide(color: _studyBorder),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _rateCard(gotIt: true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Got it'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            'Try to recall the answer before you flip the card.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _studySubtle, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildResult() => _ActivityResult(
    icon: Icons.style_rounded,
    title: widget.isReviewRound ? 'Review complete' : 'All cards mastered',
    subtitle: widget.isReviewRound
        ? 'You revisited the cards you marked for review.'
        : 'You marked every card as understood. Great work!',
    score: '${_mastered.length} / ${widget.cards.length}',
    isSaving: _isSaving,
    isSaved: _isSaved,
    saveError: _saveError,
    onRetrySave: _saveResult,
    onDone: widget.isReviewRound
        ? () => Navigator.of(context).pop()
        : _returnToDashboard,
    isPractice: widget.isReviewRound,
    doneLabel: widget.isReviewRound ? 'Back to activity summary' : null,
    followUp: !widget.isReviewRound && _reviewAgainCardIndexes.isNotEmpty
        ? FilledButton.icon(
            onPressed: _startReviewAgain,
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              'Review ${_reviewAgainCardIndexes.length} '
              '${_reviewAgainCardIndexes.length == 1 ? 'card' : 'cards'} '
              'marked for review',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _studyFill,
              foregroundColor: _studyHeading,
              side: const BorderSide(color: _studyPrimary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        : null,
  );

  void _startReviewAgain() {
    final reviewCards = _reviewAgainCardIndexes.toList()..sort();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FlashcardsScreen(
          activityId: widget.activityId,
          username: widget.username,
          email: widget.email,
          title: widget.title,
          sourceFile: widget.sourceFile,
          cards: reviewCards.map((index) => widget.cards[index]).toList(),
          role: widget.role,
          createdAt: widget.createdAt,
          onMenuSelected: widget.onMenuSelected,
          learningModeService: widget.learningModeService,
          isReviewRound: true,
        ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.card,
    required this.flipped,
    required this.onFlip,
    required this.hintVisible,
    required this.onHintPressed,
  });

  final Flashcard card;
  final bool flipped;
  final VoidCallback onFlip;
  final bool hintVisible;
  final VoidCallback onHintPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: flipped ? math.pi : 0),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, _) {
        final showAnswer = angle >= math.pi / 2;
        final content = showAnswer
            ? _buildFace(
                label: 'ANSWER',
                text: card.answer,
                explanation: card.explanation,
                icon: Icons.lightbulb_outline_rounded,
              )
            : _buildFace(
                label: 'QUESTION',
                text: card.question,
                icon: Icons.help_outline_rounded,
                hint: card.hint,
                hintVisible: hintVisible,
                onHintPressed: onHintPressed,
              );
        return GestureDetector(
          onTap: onFlip,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(showAnswer ? math.pi : 0),
              child: content,
            ),
          ),
        );
      },
    ),
  );

  Widget _buildFace({
    required String label,
    required String text,
    required IconData icon,
    String? explanation,
    String? hint,
    bool hintVisible = false,
    VoidCallback? onHintPressed,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _studyBorder, width: 1.4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1C3B2419),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _studyPrimary, size: 21),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: _studyPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Container(
          width: 52,
          height: 3,
          decoration: BoxDecoration(
            color: _studyFill,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 17),
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _studyHeading,
                fontSize: 22,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (explanation != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _studyFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explanation',
                  style: TextStyle(
                    color: _studyHeading,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  explanation,
                  style: const TextStyle(
                    color: _studySubtle,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (hintVisible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _studyBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: _studyPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        color: _studySubtle,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onHintPressed,
              icon: const Icon(Icons.tips_and_updates_outlined, size: 18),
              label: const Text('Need a hint?'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _studyPrimary,
                side: const BorderSide(color: _studyBorder),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ],
    ),
  );
}

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({
    required this.activityId,
    required this.username,
    required this.email,
    required this.title,
    required this.sourceFile,
    required this.pairs,
    this.role = 'student',
    this.createdAt,
    this.onMenuSelected,
    this.learningModeService,
    super.key,
  });

  final String activityId;
  final String username;
  final String email;
  final String title;
  final String sourceFile;
  final List<MatchingPair> pairs;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;
  final LearningModeService? learningModeService;

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  static const _batchSize = 10;

  late final List<List<int>> _answerOrders = List.generate(
    (widget.pairs.length / _batchSize).ceil(),
    (batch) {
      final start = batch * _batchSize;
      final count = math.min(_batchSize, widget.pairs.length - start);
      return List<int>.generate(count, (index) => start + index)
        ..shuffle(math.Random());
    },
  );
  final Map<int, int> _selections = {};
  final Map<int, int> _submittedAnswers = {};
  int? _selectedAnswer;
  int _batchIndex = 0;
  int _score = 0;
  bool _isFinished = false;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _saveError;

  int get _batchStart => _batchIndex * _batchSize;

  List<MatchingPair> get _currentPairs =>
      widget.pairs.skip(_batchStart).take(_batchSize).toList(growable: false);

  double get _progress =>
      (_batchStart + _selections.length) / widget.pairs.length;

  void _selectAnswer(int answerIndex) {
    if (_selections.values.contains(answerIndex)) return;
    setState(() {
      _selectedAnswer = _selectedAnswer == answerIndex ? null : answerIndex;
    });
  }

  void _placeSelectedAnswer(int promptIndex) {
    final answerIndex = _selectedAnswer;
    if (_selections.containsKey(promptIndex)) {
      setState(() => _selections.remove(promptIndex));
      return;
    }
    if (answerIndex == null) return;
    _placeAnswer(promptIndex, answerIndex);
  }

  void _placeAnswer(int promptIndex, int answerIndex) {
    if (_selections.containsKey(promptIndex) &&
        _selections[promptIndex] != answerIndex) {
      return;
    }
    if (_selections.values.contains(answerIndex)) return;
    setState(() {
      _selections[promptIndex] = answerIndex;
      if (_selectedAnswer == answerIndex) _selectedAnswer = null;
    });
  }

  void _advance() {
    if (_selections.length != _currentPairs.length) return;
    final batchSelections = Map<int, int>.of(_selections);
    final correctInBatch = batchSelections.entries
        .where((entry) => _batchStart + entry.key == entry.value)
        .length;
    for (final entry in batchSelections.entries) {
      _submittedAnswers[_batchStart + entry.key] = entry.value;
    }
    if (_batchStart + _currentPairs.length == widget.pairs.length) {
      _score += correctInBatch;
      setState(() => _isFinished = true);
      _saveResult();
      return;
    }
    setState(() {
      _score += correctInBatch;
      _batchIndex++;
      _selections.clear();
      _selectedAnswer = null;
    });
  }

  Future<void> _saveResult() async {
    if (_isSaving || _isSaved) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await (widget.learningModeService ?? LearningModeService()).saveAttempt(
        itemId: widget.activityId,
        score: _score,
        totalItems: widget.pairs.length,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });
    } on LearningModeServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = error.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Your matching result could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => StudentScaffold(
    title: _isFinished ? 'Matching complete' : 'Match the concepts',
    username: widget.username,
    email: widget.email,
    role: _displayRole(widget.role),
    onBack: () => Navigator.of(context).maybePop(_isSaved),
    onMenuSelected: (item) => _handleMenuSelection(
      context,
      item,
      username: widget.username,
      email: widget.email,
      role: widget.role,
      createdAt: widget.createdAt,
      onMenuSelected: widget.onMenuSelected,
    ),
    body: SafeArea(
      child: _isFinished
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: _buildResult(),
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildMatchingSet(),
                ),
              ),
            ),
    ),
  );

  Widget _buildMatchingSet() {
    final order = _answerOrders[_batchIndex];
    final batchNumber = _batchIndex + 1;
    final totalBatches = _answerOrders.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              _StudyHeading(
                eyebrow: 'MATCHING ACTIVITY',
                title: widget.title,
                subtitle: '${widget.pairs.length} pairs · ${widget.sourceFile}',
              ),
              const SizedBox(height: 16),
              _ProgressSummary(
                label: 'Set $batchNumber of $totalBatches',
                detail:
                    '${_selections.length} of ${_currentPairs.length} paired',
                progress: _progress,
              ),
              const SizedBox(height: 12),
              _matchingGuide(),
              const SizedBox(height: 16),
              for (var index = 0; index < _currentPairs.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _buildPairRow(index),
              ],
            ],
          ),
        ),
        _buildAnswerBank(order),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _selections.length == _currentPairs.length
              ? _advance
              : null,
          icon: Icon(
            batchNumber == totalBatches
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
          ),
          label: Text(
            batchNumber == totalBatches ? 'Finish matching' : 'Next set',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _matchingGuide() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _studyFill,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _studyBorder),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.touch_app_outlined, color: _studyPrimary, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Drag an answer onto a prompt, or tap an answer and then its prompt. Tap a filled prompt to return its answer to the bank; remove an answer before replacing it.',
            style: TextStyle(color: _studySubtle, height: 1.4, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildAnswerBank(List<int> order) {
    final usedAnswers = _selections.values.toSet();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _studyBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.widgets_outlined,
                    color: _studyPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Answer bank',
                      style: TextStyle(
                        color: _studyHeading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${order.length - usedAnswers.length} left',
                    style: const TextStyle(
                      color: _studySubtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final answerIndex in order)
                    if (!usedAnswers.contains(answerIndex))
                      _buildAnswerTile(answerIndex),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerTile(int answerIndex) {
    final selected = _selectedAnswer == answerIndex;
    final tile = InkWell(
      onTap: () => _selectAnswer(answerIndex),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _studyPrimary : _studyFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _studyPrimary : _studyBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.pan_tool_alt_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                widget.pairs[answerIndex].right,
                style: TextStyle(
                  color: selected ? Colors.white : _studyHeading,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Draggable<int>(
      data: answerIndex,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: tile,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }

  Widget _buildPairRow(int index) {
    final pair = _currentPairs[index];
    final selectedAnswer = _selections[index];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _studyBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _studyFill,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${_batchStart + index + 1}',
                  style: const TextStyle(
                    color: _studyPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pair.left,
                  style: const TextStyle(
                    color: _studyHeading,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => _placeAnswer(index, details.data),
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _placeSelectedAnswer(index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isHovering
                          ? const Color(0xFFFFE3D2)
                          : selectedAnswer != null
                          ? _studyFill
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isHovering || _selectedAnswer != null
                            ? _studyPrimary
                            : _studyBorder,
                        width: isHovering ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedAnswer != null
                              ? Icons.link_rounded
                              : Icons.add_circle_outline_rounded,
                          color: selectedAnswer != null
                              ? _studyPrimary
                              : _studySubtle,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedAnswer != null
                                ? widget.pairs[selectedAnswer].right
                                : _selectedAnswer != null
                                ? 'Tap to place selected answer'
                                : 'Drop an answer here or tap to fill',
                            style: TextStyle(
                              color: selectedAnswer != null
                                  ? _studyHeading
                                  : _studySubtle,
                              fontWeight: selectedAnswer != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selectedAnswer != null)
                          const Icon(
                            Icons.close_rounded,
                            color: _studySubtle,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResult() => _ActivityResult(
    icon: Icons.extension_rounded,
    title: 'Matching complete',
    subtitle:
        'You finished every set. Review your score and try again whenever you like.',
    score: '$_score / ${widget.pairs.length}',
    review: SizedBox(
      height: (MediaQuery.sizeOf(context).height * 0.42)
          .clamp(220.0, 420.0)
          .toDouble(),
      child: SingleChildScrollView(
        key: const ValueKey('matching-result-review-scroll'),
        child: _buildMatchingReview(),
      ),
    ),
    isSaving: _isSaving,
    isSaved: _isSaved,
    saveError: _saveError,
    onRetrySave: _saveResult,
    onDone: () => Navigator.of(context).pop(true),
  );

  Widget _buildMatchingReview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Review your matches',
        style: TextStyle(
          color: _studyHeading,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < widget.pairs.length; index++) ...[
        if (index > 0) const SizedBox(height: 10),
        _MatchingReviewCard(
          index: index,
          pair: widget.pairs[index],
          selectedAnswer: widget.pairs[_submittedAnswers[index]!].right,
          isCorrect: _submittedAnswers[index] == index,
        ),
      ],
    ],
  );
}

class _MatchingReviewCard extends StatelessWidget {
  const _MatchingReviewCard({
    required this.index,
    required this.pair,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  final int index;
  final MatchingPair pair;
  final String selectedAnswer;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0F7F0) : const Color(0xFFFFF3F1),
        border: Border.all(
          color: isCorrect ? const Color(0xFFC8DEC8) : const Color(0xFFEBC9C4),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pair ${index + 1}: ${pair.left}',
            style: const TextStyle(
              color: _studyHeading,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your answer: $selectedAnswer',
            style: TextStyle(
              color: isCorrect ? const Color(0xFF2E7D32) : _studySubtle,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 4),
            Text(
              'Correct answer: ${pair.right}',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            pair.explanation,
            style: const TextStyle(color: _studySubtle, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StudyHeading extends StatelessWidget {
  const _StudyHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: _studyPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: const TextStyle(
          color: _studyHeading,
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: _studySubtle)),
    ],
  );
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.label,
    required this.detail,
    required this.progress,
  });

  final String label;
  final String detail;
  final double progress;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _studyHeading,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(detail, style: const TextStyle(color: _studySubtle)),
        ],
      ),
      const SizedBox(height: 9),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 8,
          color: _studyPrimary,
          backgroundColor: _studyFill,
        ),
      ),
    ],
  );
}

class _ActivityResult extends StatelessWidget {
  const _ActivityResult({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.score,
    this.review,
    this.followUp,
    required this.isSaving,
    required this.isSaved,
    required this.saveError,
    required this.onRetrySave,
    required this.onDone,
    this.isPractice = false,
    this.doneLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String score;
  final Widget? review;
  final Widget? followUp;
  final bool isSaving;
  final bool isSaved;
  final String? saveError;
  final VoidCallback onRetrySave;
  final VoidCallback onDone;
  final bool isPractice;
  final String? doneLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _studyBorder),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _studyFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: _studyPrimary, size: 32),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _studyHeading,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _studySubtle, height: 1.45),
        ),
        const SizedBox(height: 20),
        Text(
          score,
          style: const TextStyle(
            color: _studyPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (review != null) ...[const SizedBox(height: 24), review!],
        if (isPractice) ...[
          const SizedBox(height: 8),
          const Text(
            'This review round was not added to your activity history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _studySubtle, fontSize: 13),
          ),
        ] else if (saveError != null) ...[
          const SizedBox(height: 12),
          Text(
            'Result not saved: $saveError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB42318)),
          ),
          TextButton.icon(
            onPressed: isSaving ? null : onRetrySave,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(isSaving ? 'Saving...' : 'Retry saving result'),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            isSaved
                ? 'Saved to your learning activity.'
                : 'Saving your result...',
            style: const TextStyle(color: _studySubtle, fontSize: 13),
          ),
          if (isSaving)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
        if (followUp != null) ...[
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: followUp),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isPractice || isSaved ? onDone : null,
            child: Text(doneLabel ?? 'Back to dashboard'),
          ),
        ),
      ],
    ),
  );
}

void _handleMenuSelection(
  BuildContext context,
  StudentMenuItem item, {
  required String username,
  required String email,
  required String role,
  required DateTime? createdAt,
  required ValueChanged<StudentMenuItem>? onMenuSelected,
}) {
  if (item == StudentMenuItem.profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          username: username,
          email: email,
          role: role,
          createdAt: createdAt,
          onMenuSelected: onMenuSelected,
        ),
      ),
    );
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
  onMenuSelected?.call(item);
}

String _displayRole(String role) => role.isEmpty
    ? role
    : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
