import 'package:kioku_japanese/models/quiz_question.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-26 학습 세션의 현재 화면 상태를 불변 데이터로 보관한다.
class LearningSessionState {
  const LearningSessionState({
    required this.newWords,
    required this.questions,
    required this.currentIndex,
    required this.results,
    required this.isLoading,
    required this.isComplete,
    required this.currentAnswered,
    required this.lastAnswerCorrect,
    required this.submittedAnswer,
  });

  final List<Vocabulary> newWords;
  final List<QuizQuestion> questions;
  final int currentIndex;
  final List<ReviewResult> results;
  final bool isLoading;
  final bool isComplete;
  final bool currentAnswered;
  final bool? lastAnswerCorrect;
  final String? submittedAnswer;

  /// 2026-09-26 아직 시작하지 않은 빈 세션을 만든다.
  factory LearningSessionState.initial() {
    return const LearningSessionState(
      newWords: <Vocabulary>[],
      questions: <QuizQuestion>[],
      currentIndex: 0,
      results: <ReviewResult>[],
      isLoading: false,
      isComplete: false,
      currentAnswered: false,
      lastAnswerCorrect: null,
      submittedAnswer: null,
    );
  }

  /// 2026-09-26 현재 문제를 안전하게 반환한다.
  QuizQuestion? get currentQuestion {
    if (isComplete || currentIndex < 0 || currentIndex >= questions.length) {
      return null;
    }
    return questions[currentIndex];
  }

  /// 2026-09-26 필요한 필드만 바꾼 새로운 세션 상태를 만든다.
  LearningSessionState copyWith({
    List<Vocabulary>? newWords,
    List<QuizQuestion>? questions,
    int? currentIndex,
    List<ReviewResult>? results,
    bool? isLoading,
    bool? isComplete,
    bool? currentAnswered,
    bool? lastAnswerCorrect,
    String? submittedAnswer,
    bool clearAnswerState = false,
  }) {
    return LearningSessionState(
      newWords: newWords ?? this.newWords,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isComplete: isComplete ?? this.isComplete,
      currentAnswered: clearAnswerState
          ? false
          : currentAnswered ?? this.currentAnswered,
      lastAnswerCorrect:
          clearAnswerState ? null : lastAnswerCorrect ?? this.lastAnswerCorrect,
      submittedAnswer:
          clearAnswerState ? null : submittedAnswer ?? this.submittedAnswer,
    );
  }
}
