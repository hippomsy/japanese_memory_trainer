import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/quiz_question.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/memory_evaluator.dart';
import 'package:kioku_japanese/services/quiz_generator.dart';
import 'package:kioku_japanese/widgets/memory_answer_buttons.dart';

/// 2026-09-26 최근 위험도가 높은 단어를 최대 10개 집중 복습하는 주간 보스전 화면이다.
class BossPage extends StatefulWidget {
  const BossPage({
    super.key,
    required this.repository,
    required this.database,
    required this.evaluator,
    required this.quizGenerator,
  });

  final LearningRepository repository;
  final LocalDatabase database;
  final MemoryEvaluator evaluator;
  final QuizGenerator quizGenerator;

  @override
  State<BossPage> createState() => _BossPageState();
}

class _BossPageState extends State<BossPage> {
  final TextEditingController _answerController = TextEditingController();
  List<QuizQuestion> _questions = const [];
  Map<String, MemoryState> _states = <String, MemoryState>{};
  bool _loading = true;
  bool _answered = false;
  bool _completed = false;
  bool _lastCorrect = false;
  int _index = 0;
  int _conquered = 0;
  int _needsPractice = 0;
  String? _saveError;
  DateTime _shownAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  /// 2026-09-26 repository가 고른 위험 단어를 기존 QuizGenerator의 한→일 문제로 만든다.
  Future<void> _load() async {
    try {
      final words = await widget.repository.getBossWords(limit: 10);
      final states = await widget.repository.getMemoryStates();
      if (!mounted) return;
      setState(() {
        _states = states;
        _questions = words
            .map(
              (word) => widget.quizGenerator.buildQuestion(
                word,
                QuizDirection.koreanToJapanese,
              ),
            )
            .toList(growable: false);
        _loading = false;
        _completed = _questions.isEmpty;
        _shownAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _completed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('주간 보스전')),
        body: const Center(child: Text('이번 주 보스 단어가 없습니다.')),
      );
    }
    if (_completed) {
      return _BossResult(
        conquered: _conquered,
        needsPractice: _needsPractice,
      );
    }

    final question = _questions[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('주간 보스전')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${_index + 1} / ${_questions.length}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_index + 1) / _questions.length),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Text('한국어 → 일본어'),
                  const SizedBox(height: 12),
                  Text(
                    question.prompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _answerController,
            enabled: !_answered,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '일본어 답 입력',
            ),
          ),
          const SizedBox(height: 12),
          MemoryAnswerButtons(
            enabled: !_answered,
            onSelected: (feeling) {
              _submit(feeling);
            },
          ),
          if (_answered) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _lastCorrect ? '정복 성공!' : '정답: ${question.correctAnswer}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(_saveError!),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _next,
              child: Text(
                _index == _questions.length - 1 ? '결과 보기' : '다음',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 2026-09-26 보스전도 기존 MemoryEvaluator를 사용해 일반 복습과 같은 기억 규칙을 적용한다.
  Future<void> _submit(MemoryFeeling feeling) async {
    if (_answered) return;
    final question = _questions[_index];
    final isCorrect = _normalize(_answerController.text) ==
        _normalize(question.correctAnswer);
    final now = DateTime.now();
    final result = ReviewResult(
      wordId: question.wordId,
      direction: question.direction,
      isCorrect: isCorrect,
      responseMs: now.difference(_shownAt).inMilliseconds.clamp(0, 1 << 31).toInt(),
      feeling: feeling,
      reviewedAt: now,
    );
    final current = _states[question.wordId] ?? MemoryState.initial(question.wordId);
    final updated = widget.evaluator.applyResult(current, result);

    setState(() {
      _states = <String, MemoryState>{..._states, question.wordId: updated};
      _answered = true;
      _lastCorrect = isCorrect;
      if (isCorrect) {
        _conquered++;
      } else {
        _needsPractice++;
      }
      _saveError = null;
    });

    try {
      await widget.database.saveMemoryStates(_states);
      await widget.database.recordLearningDay(now);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveError = '보스전 결과를 저장하지 못했습니다: $error');
    }
  }

  /// 2026-09-26 답 확인 후 다음 보스로 이동하거나 최종 결과를 표시한다.
  void _next() {
    if (_index >= _questions.length - 1) {
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _lastCorrect = false;
      _answerController.clear();
      _shownAt = DateTime.now();
    });
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }
}

class _BossResult extends StatelessWidget {
  const _BossResult({required this.conquered, required this.needsPractice});

  final int conquered;
  final int needsPractice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('보스전 결과')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 72),
            const SizedBox(height: 14),
            Text('정복 $conquered개', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('연습 필요 $needsPractice개'),
          ],
        ),
      ),
    );
  }
}
