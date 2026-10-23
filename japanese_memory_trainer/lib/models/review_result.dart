/// 2026-09-26 학습 문제의 출제 방향을 정의한다.
enum QuizDirection {
  japaneseToKorean,
  koreanToJapanese,
  sentenceBlank,
  listening,
}

/// 2026-09-26 사용자가 느낀 기억 난이도를 정의한다.
enum MemoryFeeling {
  didNotKnow,
  hardRecall,
  remembered,
  instantRecall,
}

/// 2026-09-26 문제 한 번의 답변 결과를 기록한다.
class ReviewResult {
  const ReviewResult({
    required this.wordId,
    required this.direction,
    required this.isCorrect,
    required this.responseMs,
    required this.feeling,
    required this.reviewedAt,
  });

  final String wordId;
  final QuizDirection direction;
  final bool isCorrect;
  final int responseMs;
  final MemoryFeeling feeling;
  final DateTime reviewedAt;
}
