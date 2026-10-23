import 'package:flutter/foundation.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/learning_session_state.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/quiz_question.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/memory_evaluator.dart';
import 'package:kioku_japanese/services/quiz_generator.dart';

/// 2026-09-26 오늘의 학습 문제 진행과 저장 순서를 관리한다.
class LearningSessionController extends ChangeNotifier {
  LearningSessionController({
    required LearningRepository repository,
    required LocalDatabase database,
    required MemoryEvaluator evaluator,
    required QuizGenerator quizGenerator,
    this.newWordLimit = 5,
  })  : _repository = repository,
        _database = database,
        _evaluator = evaluator,
        _quizGenerator = quizGenerator;

  final LearningRepository _repository;
  final LocalDatabase _database;
  final MemoryEvaluator _evaluator;
  final QuizGenerator _quizGenerator;
  final int newWordLimit;

  LearningSessionState _state = LearningSessionState.initial();
  Map<String, MemoryState> _memoryStates = <String, MemoryState>{};
  String? _persistenceError;

  LearningSessionState get state => _state;
  String? get persistenceError => _persistenceError;

  /// 2026-09-26 신규 단어를 먼저 배치하고 그 뒤에 기한이 된 복습 문제를 붙인다.
  Future<void> startTodayQuest(DateTime now) async {
    _persistenceError = null;
    _state = LearningSessionState.initial().copyWith(isLoading: true);
    notifyListeners();

    try {
      _memoryStates = await _database.loadMemoryStates();
      final newWords = await _repository.getNewWordsForDay(
        now,
        limit: newWordLimit,
      );
      final newIds = newWords.map((word) => word.id).toSet();
      final dueWords = (await _repository.getDueWords(now))
          .where((word) => !newIds.contains(word.id))
          .toList(growable: false);

      final questions = <QuizQuestion>[];
      for (final word in newWords) {
        questions.add(
          _quizGenerator.buildQuestion(word, QuizDirection.japaneseToKorean),
        );
        questions.add(
          _quizGenerator.buildQuestion(word, QuizDirection.koreanToJapanese),
        );
        questions.add(
          _quizGenerator.buildQuestion(word, QuizDirection.sentenceBlank),
        );
        questions.add(
          _quizGenerator.buildQuestion(word, QuizDirection.listening),
        );
      }

      const reviewDirections = <QuizDirection>[
        QuizDirection.koreanToJapanese,
        QuizDirection.listening,
        QuizDirection.japaneseToKorean,
        QuizDirection.sentenceBlank,
      ];
      for (var index = 0; index < dueWords.length; index++) {
        questions.add(
          _quizGenerator.buildQuestion(
            dueWords[index],
            reviewDirections[index % reviewDirections.length],
          ),
        );
      }

      _state = LearningSessionState(
        newWords: List.unmodifiable(newWords),
        questions: List<QuizQuestion>.unmodifiable(questions),
        currentIndex: 0,
        results: const <ReviewResult>[],
        isLoading: false,
        isComplete: questions.isEmpty,
        currentAnswered: false,
        lastAnswerCorrect: null,
        submittedAnswer: null,
      );
    } catch (error) {
      _persistenceError = '학습 데이터를 불러오지 못했습니다: $error';
      _state = LearningSessionState.initial().copyWith(
        isLoading: false,
        isComplete: true,
      );
    }
    notifyListeners();
  }

  /// 2026-09-26 메모리 상태를 먼저 갱신한 뒤 디스크 저장을 시도해 저장 실패에도 화면 결과를 보존한다.
  Future<void> submitAnswer({
    required String answer,
    required MemoryFeeling feeling,
    required int responseMs,
    required DateTime now,
  }) async {
    final question = _state.currentQuestion;
    if (question == null || _state.currentAnswered) return;

    final isCorrect = _isCorrectAnswer(answer, question.correctAnswer);
    final result = ReviewResult(
      wordId: question.wordId,
      direction: question.direction,
      isCorrect: isCorrect,
      responseMs: responseMs < 0 ? 0 : responseMs,
      feeling: feeling,
      reviewedAt: now,
    );

    final current = _memoryStates[question.wordId] ??
        MemoryState.initial(question.wordId);
    final updated = _evaluator.applyResult(current, result);

    _memoryStates = <String, MemoryState>{
      ..._memoryStates,
      question.wordId: updated,
    };

    _state = _state.copyWith(
      results: List<ReviewResult>.unmodifiable(<ReviewResult>[
        ..._state.results,
        result,
      ]),
      currentAnswered: true,
      lastAnswerCorrect: isCorrect,
      submittedAnswer: answer,
    );
    _persistenceError = null;
    notifyListeners();

    try {
      await _database.saveMemoryStates(_memoryStates);
      await _database.recordLearningDay(now);
    } catch (error) {
      _persistenceError = '학습 결과를 저장하지 못했습니다: $error';
      notifyListeners();
    }
  }

  /// 2026-09-26 현재 문제 다음으로 이동하고 마지막 문제 뒤에는 완료 상태로 전환한다.
  void moveNext() {
    if (_state.isComplete) return;
    if (_state.questions.isEmpty ||
        _state.currentIndex >= _state.questions.length - 1) {
      _state = _state.copyWith(
        isComplete: true,
        clearAnswerState: true,
      );
    } else {
      _state = _state.copyWith(
        currentIndex: _state.currentIndex + 1,
        clearAnswerState: true,
      );
    }
    notifyListeners();
  }

  /// 2026-09-26 화면에서 저장 오류 안내를 확인한 뒤 메시지만 지운다.
  void clearPersistenceError() {
    _persistenceError = null;
    notifyListeners();
  }

  bool _isCorrectAnswer(String answer, String correctAnswer) {
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
}
