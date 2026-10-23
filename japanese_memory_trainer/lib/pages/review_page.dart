import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/services/learning_session_controller.dart';

/// 2026-09-26 미리보기와 같이 4지선다로 일본어 기억을 확인하는 복습 화면이다.
class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.controller,
    required this.speakJapanese,
    required this.onFinished,
    this.now,
  });

  final LearningSessionController controller;
  final Future<void> Function(String text) speakJapanese;
  final VoidCallback onFinished;
  final DateTime Function()? now;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late DateTime _shownAt;
  bool _submitting = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _shownAt = _now;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.isComplete || state.currentQuestion == null) {
          return _CompletionView(
            results: state.results,
            onFinished: widget.onFinished,
          );
        }

        final question = state.currentQuestion!;
        final answered = state.currentAnswered;
        final submittedAnswer = state.submittedAnswer;
        final progress = (state.currentIndex + 1) / state.questions.length;

        return Scaffold(
          backgroundColor: const Color(0xFFFFFAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFFAFC),
            surfaceTintColor: Colors.transparent,
            title: Text(_directionTitle(question.direction)),
            centerTitle: true,
          ),
          // 2026-09-27 정답 확인 후 '다음 문제' 버튼과 저장 오류 안내가 스크롤 아래로 밀려
          // 보이지 않는 일이 없도록, 화면 하단에 고정해서 항상 보이게 한다.
          bottomNavigationBar: answered
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.controller.persistenceError != null) ...[
                          MaterialBanner(
                            content: Text(widget.controller.persistenceError!),
                            actions: [
                              TextButton(
                                onPressed: widget.controller.clearPersistenceError,
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _next,
                          child: const Text(
                            '다음 문제  →',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 9,
                          value: progress,
                          backgroundColor: Colors.pink.shade50,
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${state.currentIndex + 1}/${state.questions.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _QuestionHeader(
                  direction: question.direction,
                  prompt: question.prompt,
                  ttsText: question.ttsText,
                  exampleKorean: question.exampleKorean,
                  onSpeak: question.ttsText == null
                      ? null
                      : () => _speak(question.ttsText!),
                ),
                const SizedBox(height: 20),
                for (var index = 0; index < question.choices.length; index++) ...[
                  _QuizChoiceTile(
                    number: index + 1,
                    text: question.choices[index],
                    enabled: !answered && !_submitting,
                    isCorrectChoice:
                        answered && _answersMatch(question.choices[index], question.correctAnswer),
                    isWrongSelected: answered &&
                        submittedAnswer != null &&
                        _answersMatch(question.choices[index], submittedAnswer) &&
                        !_answersMatch(question.choices[index], question.correctAnswer),
                    onTap: () => _submitChoice(question.choices[index]),
                  ),
                  const SizedBox(height: 10),
                ],
                if (answered) ...[
                  const SizedBox(height: 8),
                  _FeedbackCard(
                    correct: state.lastAnswerCorrect ?? false,
                    correctAnswer: question.correctAnswer,
                    exampleJapanese: question.exampleJapanese,
                    exampleKorean: question.exampleKorean,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 2026-09-26 선택 즉시 정답 여부와 반응시간을 기억 엔진에 기록한다.
  Future<void> _submitChoice(String choice) async {
    if (_submitting || widget.controller.state.currentAnswered) return;
    setState(() => _submitting = true);

    final question = widget.controller.state.currentQuestion;
    if (question == null) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final responseMs = _now.difference(_shownAt).inMilliseconds.clamp(0, 1 << 31).toInt();
    final correct = _answersMatch(choice, question.correctAnswer);
    final feeling = !correct
        ? MemoryFeeling.didNotKnow
        : responseMs <= 3000
            ? MemoryFeeling.instantRecall
            : responseMs <= 5000
                ? MemoryFeeling.remembered
                : MemoryFeeling.hardRecall;

    await widget.controller.submitAnswer(
      answer: choice,
      feeling: feeling,
      responseMs: responseMs,
      now: _now,
    );

    if (mounted) setState(() => _submitting = false);
  }

  /// 2026-09-26 정답 확인 뒤 다음 객관식 문제로 이동하고 반응시간을 새로 잰다.
  void _next() {
    widget.controller.moveNext();
    if (widget.controller.state.isComplete) return;
    _shownAt = _now;
  }

  Future<void> _speak(String text) async {
    try {
      await widget.speakJapanese(text);
    } catch (_) {
      // 2026-09-26 TTS 오류는 객관식 학습 흐름을 막지 않는다.
    }
  }

  bool _answersMatch(String answer, String correctAnswer) {
    String normalize(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');

    final input = normalize(answer);
    final variants = correctAnswer
        .split(RegExp(r'[,/、·]'))
        .map(normalize)
        .where((value) => value.isNotEmpty);
    return variants.contains(input) || normalize(correctAnswer) == input;
  }

  String _directionTitle(QuizDirection direction) {
    switch (direction) {
      case QuizDirection.japaneseToKorean:
        return '일본어 → 한국어 퀴즈';
      case QuizDirection.koreanToJapanese:
        return '한국어 → 일본어 퀴즈';
      case QuizDirection.sentenceBlank:
        return '문장 빈칸 퀴즈';
      case QuizDirection.listening:
        return '듣고 맞히기';
    }
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({
    required this.direction,
    required this.prompt,
    required this.ttsText,
    required this.exampleKorean,
    required this.onSpeak,
  });

  final QuizDirection direction;
  final String prompt;
  final String? ttsText;
  final String exampleKorean;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final listening = direction == QuizDirection.listening;
    final sentence = direction == QuizDirection.sentenceBlank;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: Column(
        children: [
          if (listening) ...[
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                fixedSize: const Size(68, 68),
              ),
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up_rounded, size: 34),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  prompt,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                ),
              ),
              if (!listening && ttsText != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: '발음 듣기',
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded, color: Colors.blue),
                ),
              ],
            ],
          ),
          if (sentence) ...[
            const SizedBox(height: 10),
            Text(
              exampleKorean,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.blueGrey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizChoiceTile extends StatelessWidget {
  const _QuizChoiceTile({
    required this.number,
    required this.text,
    required this.enabled,
    required this.isCorrectChoice,
    required this.isWrongSelected,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool enabled;
  final bool isCorrectChoice;
  final bool isWrongSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = Colors.blueGrey.shade100;
    Color background = Colors.white;
    Color foreground = Colors.black87;
    IconData? trailing;

    if (isCorrectChoice) {
      border = Colors.green;
      background = Colors.green.shade50;
      foreground = Colors.green.shade800;
      trailing = Icons.check_circle;
    } else if (isWrongSelected) {
      border = Colors.redAccent;
      background = Colors.red.shade50;
      foreground = Colors.red.shade800;
      trailing = Icons.cancel;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: isCorrectChoice || isWrongSelected ? 1.8 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCorrectChoice
                      ? Colors.green.shade100
                      : isWrongSelected
                          ? Colors.red.shade100
                          : Colors.blueGrey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(fontWeight: FontWeight.w700, color: foreground),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                ),
              ),
              if (trailing != null) Icon(trailing, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.correct,
    required this.correctAnswer,
    required this.exampleJapanese,
    required this.exampleKorean,
  });

  final bool correct;
  final String correctAnswer;
  final String exampleJapanese;
  final String exampleKorean;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.info_outline,
                color: correct ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? '정답입니다!' : '정답: $correctAnswer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(exampleJapanese),
          Text(exampleKorean),
        ],
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.results, required this.onFinished});

  final List<ReviewResult> results;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final correct = results.where((result) => result.isCorrect).length;
    final percent = results.isEmpty ? 0 : ((correct / results.length) * 100).round();
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAFC),
        title: const Text('오늘 학습 완료'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFFFFE4EC),
                child: Icon(Icons.emoji_events_rounded, size: 52, color: Colors.pinkAccent),
              ),
              const SizedBox(height: 18),
              Text(
                '오늘의 학습 완료!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text('정답 $correct / ${results.length}  ·  정답률 $percent%'),
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  minimumSize: const Size(220, 52),
                ),
                onPressed: onFinished,
                child: const Text('홈으로 가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
