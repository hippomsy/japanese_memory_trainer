import 'package:kioku_japanese/models/review_result.dart';

/// 2026-09-26 화면에 표시할 문제와 정답 정보를 분리해 보관한다.
class QuizQuestion {
  const QuizQuestion({
    required this.wordId,
    required this.direction,
    required this.prompt,
    required this.correctAnswer,
    required this.choices,
    required this.ttsText,
    required this.exampleJapanese,
    required this.exampleKorean,
  });

  final String wordId;
  final QuizDirection direction;
  final String prompt;
  final String correctAnswer;
  final List<String> choices;
  final String? ttsText;
  final String exampleJapanese;
  final String exampleKorean;
}
