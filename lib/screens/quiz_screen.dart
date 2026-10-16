import 'package:flutter/material.dart';

import '../services/quiz_service.dart';
import '../widgets/student_side_menu.dart';
import 'profile_screen.dart';

const _primary = Color(0xFFFF7434);
const _inputFill = Color(0xFFFFF1DF);
const _border = Color(0xFFE8D7C2);
const _heading = Color(0xFF3B2419);
const _subtle = Color(0xFF725F53);

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.username,
    required this.email,
    required this.title,
    required this.sourceFile,
    required this.questions,
    this.quizId,
    this.previousAttempts = const [],
    this.role = 'student',
    this.createdAt,
    this.onMenuSelected,
    super.key,
  });

  final String username;
  final String email;
  final String title;
  final String sourceFile;
  final List<QuizQuestion> questions;
  final String? quizId;
  final List<QuizScore> previousAttempts;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _service = QuizService();
  late final List<int?> _answers = List<int?>.filled(
    widget.questions.length,
    null,
  );
  int _questionIndex = 0;
  bool _showResults = false;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _savedQuizId;
  String? _saveError;

  QuizQuestion get _question => widget.questions[_questionIndex];

  int get _score => List.generate(widget.questions.length, (index) => index)
      .where((index) => _answers[index] == widget.questions[index].answerIndex)
      .length;

  Future<void> _finishQuiz() async {
    if (_isSaving || _isSaved) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      _savedQuizId = await _service.saveAttempt(
        title: widget.title,
        sourceFile: widget.sourceFile,
        score: _score,
        totalQuestions: widget.questions.length,
        questions: widget.questions,
        quizId: _savedQuizId ?? widget.quizId,
      );
      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _isSaving = false;
        _showResults = true;
      });
    } on QuizServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = error.message;
        _isSaving = false;
        _showResults = true;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _saveError = 'Your score could not be saved. Please try again.';
        _isSaving = false;
        _showResults = true;
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    if (_answers[_questionIndex] != null) return;
    setState(() => _answers[_questionIndex] = answerIndex);
  }

  void _goToNextQuestion() {
    if (_questionIndex == widget.questions.length - 1) {
      _finishQuiz();
      return;
    }
    setState(() => _questionIndex++);
  }

  void _returnToDashboard() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: _showResults ? 'Quiz Results' : 'Take your quiz',
      username: widget.username,
      email: widget.email,
      role: _displayRole(widget.role),
      onBack: () => Navigator.of(context).maybePop(false),
      onMenuSelected: (item) {
        if (item == StudentMenuItem.dashboard) {
          Navigator.of(context).maybePop(false);
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
              child: _showResults ? _buildResults() : _buildQuestion(),
            ),
          ),
        ),
      ),
    );
  }

  String _displayRole(String role) => role.isEmpty
      ? role
      : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';

  Widget _buildQuestion() {
    final selectedAnswer = _answers[_questionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuizHeading(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (_questionIndex + 1) / widget.questions.length,
                  minHeight: 10,
                  backgroundColor: _border,
                  valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${_questionIndex + 1} / ${widget.questions.length}',
              style: const TextStyle(
                color: _subtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUESTION ${_questionIndex + 1}',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _question.question,
                style: const TextStyle(
                  color: _heading,
                  fontSize: 22,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              ...List<Widget>.generate(
                _question.options.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnswerOption(
                    index: index,
                    label: _question.options[index],
                    selectedAnswer: selectedAnswer,
                    correctAnswer: _question.answerIndex,
                    onTap: () => _selectAnswer(index),
                  ),
                ),
              ),
              if (selectedAnswer != null) ...[
                const SizedBox(height: 8),
                _buildFeedback(selectedAnswer),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _goToNextQuestion,
                    style: _buttonStyle,
                    icon: Icon(
                      _questionIndex == widget.questions.length - 1
                          ? Icons.emoji_events_outlined
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _questionIndex == widget.questions.length - 1
                          ? 'See your score'
                          : 'Next question',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizHeading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _inputFill,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Text(
          'MULTIPLE-CHOICE QUIZ',
          style: TextStyle(
            color: _primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        widget.title,
        style: const TextStyle(
          color: _heading,
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Based on ${widget.sourceFile}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: _subtle),
      ),
    ],
  );

  Widget _buildFeedback(int selectedAnswer) {
    final isCorrect = selectedAnswer == _question.answerIndex;
    final color = isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFA33A2B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct!' : 'Not quite',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              'Correct answer: ${_question.options[_question.answerIndex]}',
              style: const TextStyle(
                color: _heading,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _question.explanation,
            style: const TextStyle(color: _subtle, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final percent = (_score / widget.questions.length * 100).round();
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: _cardDecoration,
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _inputFill,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Quiz complete!',
                style: TextStyle(
                  color: _heading,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _subtle),
              ),
              const SizedBox(height: 22),
              Text(
                '$_score / ${widget.questions.length}',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent% correct',
                style: const TextStyle(
                  color: _heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.previousAttempts.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildPreviousAttempts(),
              ],
              const SizedBox(height: 24),
              if (_saveError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1DF),
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score not saved to recent activity: $_saveError',
                    style: const TextStyle(color: _heading, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _finishQuiz,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Retry saving score'),
                ),
                const SizedBox(height: 12),
              ] else
                Text(
                  _isSaved
                      ? 'Your score was saved to recent activity.'
                      : 'Saving your score...',
                  style: const TextStyle(color: _subtle),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _returnToDashboard,
                  style: _buttonStyle,
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Return to dashboard'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousAttempts() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8EE),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previous attempts (${widget.previousAttempts.length})',
          style: const TextStyle(
            color: _heading,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.previousAttempts.asMap().entries.map((entry) {
          final attempt = entry.value;
          final percentage = (attempt.score / attempt.totalQuestions * 100)
              .round();
          return Padding(
            padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${attempt.score} / ${attempt.totalQuestions} correct · ${_formatAttemptDate(attempt.createdAt)}',
                    style: const TextStyle(color: _subtle, fontSize: 13),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  String _formatAttemptDate(DateTime date) {
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
    final localDate = date.toLocal();
    return '${months[localDate.month - 1]} ${localDate.day}';
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.label,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.onTap,
  });

  final int index;
  final String label;
  final int? selectedAnswer;
  final int correctAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAnswered = selectedAnswer != null;
    final isCorrectAnswer = index == correctAnswer;
    final isSelectedAnswer = index == selectedAnswer;
    final isSelectedCorrect = hasAnswered && isCorrectAnswer;
    final isSelectedWrong = isSelectedAnswer && !isCorrectAnswer;
    final color = isSelectedCorrect
        ? const Color(0xFF2E7D32)
        : isSelectedWrong
        ? const Color(0xFFA33A2B)
        : _border;
    final fill = isSelectedCorrect
        ? const Color(0xFFEAF5E9)
        : isSelectedWrong
        ? const Color(0xFFFFEFEC)
        : _inputFill;

    return InkWell(
      onTap: hasAnswered ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: color,
            width: isSelectedCorrect || isSelectedWrong ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasAnswered && isCorrectAnswer ? color : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: hasAnswered && isCorrectAnswer
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        color: isSelectedWrong ? color : _subtle,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _heading,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelectedWrong)
              Icon(Icons.close_rounded, color: color)
            else if (isSelectedCorrect)
              Icon(Icons.check_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  border: Border.fromBorderSide(BorderSide(color: _border)),
  boxShadow: [
    BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

final _buttonStyle = FilledButton.styleFrom(
  backgroundColor: _primary,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
);
