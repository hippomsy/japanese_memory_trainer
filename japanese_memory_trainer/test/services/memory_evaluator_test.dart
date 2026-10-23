import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/services/memory_evaluator.dart';

ReviewResult result({
  required QuizDirection direction,
  required bool correct,
  required int responseMs,
  required MemoryFeeling feeling,
  DateTime? at,
}) {
  return ReviewResult(
    wordId: 'w1',
    direction: direction,
    isCorrect: correct,
    responseMs: responseMs,
    feeling: feeling,
    reviewedAt: at ?? DateTime(2026, 9, 26, 8),
  );
}

void main() {
  final evaluator = MemoryEvaluator();

  // 2026-09-27 Stage 0~7 고정 전이 대신 FSRS stability/difficulty로 다음
  // 복습 시점을 계산하므로, 아래 테스트들은 고정 stage 증감 대신 FSRS가
  // 보장하는 성질(정답이면 stability가 줄지 않는다, 오답이면 위험도가
  // 오른다 등)을 검증하도록 다시 작성했다.

  test('first correct instant recall on a brand-new word sets a positive stability and long stage bucket', () {
    final updated = evaluator.applyResult(
      MemoryState.initial('w1'),
      result(
        direction: QuizDirection.koreanToJapanese,
        correct: true,
        responseMs: 1200,
        feeling: MemoryFeeling.instantRecall,
      ),
    );
    expect(updated.stability, greaterThan(0));
    // requestRetention 기본값(0.9)에서는 간격(일)==stability(일)이 정확히
    // 성립하므로, Easy 등급의 초기 stability(약 15.47일)는 stage 버킷 5에 든다.
    expect(updated.stage, 5);
  });

  test('wrong answer never grows stability and raises dangerScore', () {
    final current = MemoryState.initial('w1').copyWith(
      stability: 20,
      difficulty: 5,
      dangerScore: 20,
    );
    final updated = evaluator.applyResult(
      current,
      result(
        direction: QuizDirection.japaneseToKorean,
        correct: false,
        responseMs: 2500,
        feeling: MemoryFeeling.didNotKnow,
      ),
    );
    expect(updated.stability, lessThan(current.stability));
    expect(updated.dangerScore, greaterThan(20));
    expect(updated.lapses, current.lapses + 1);
  });

  test('correct answer taking more than 5000ms raises danger relative to fast answer', () {
    final current = MemoryState.initial('w1').copyWith(
      stability: 10,
      difficulty: 5,
      dangerScore: 20,
    );
    final fast = evaluator.applyResult(
      current,
      result(
        direction: QuizDirection.japaneseToKorean,
        correct: true,
        responseMs: 1500,
        feeling: MemoryFeeling.remembered,
      ),
    );
    final slow = evaluator.applyResult(
      current,
      result(
        direction: QuizDirection.japaneseToKorean,
        correct: true,
        responseMs: 5200,
        feeling: MemoryFeeling.remembered,
      ),
    );
    expect(slow.dangerScore, greaterThan(fast.dangerScore));
  });

  test('koreanToJapanese correct recall improves recallScore more than japaneseToKorean improves it', () {
    final current = MemoryState.initial('w1');
    final recall = evaluator.applyResult(
      current,
      result(
        direction: QuizDirection.koreanToJapanese,
        correct: true,
        responseMs: 1200,
        feeling: MemoryFeeling.remembered,
      ),
    );
    final recognition = evaluator.applyResult(
      current,
      result(
        direction: QuizDirection.japaneseToKorean,
        correct: true,
        responseMs: 1200,
        feeling: MemoryFeeling.remembered,
      ),
    );
    expect(recall.recallScore, greaterThan(recognition.recallScore));
    expect(recall.recallScore, 10);
  });

  test('recognition success plus repeated recall failure raises dangerScore', () {
    var state = MemoryState.initial('w1');
    state = evaluator.applyResult(
      state,
      result(
        direction: QuizDirection.japaneseToKorean,
        correct: true,
        responseMs: 1200,
        feeling: MemoryFeeling.remembered,
      ),
    );
    final beforeFailures = state.dangerScore;
    for (var i = 0; i < 3; i++) {
      state = evaluator.applyResult(
        state,
        result(
          direction: QuizDirection.koreanToJapanese,
          correct: false,
          responseMs: 4000,
          feeling: MemoryFeeling.didNotKnow,
          at: DateTime(2026, 9, 26, 9, i),
        ),
      );
    }
    expect(state.dangerScore, greaterThan(beforeFailures));
    expect(state.recallScore, lessThan(state.recognitionScore));
  });

  test('reviewing well before nextReviewAt still recomputes it but never shortens stability', () {
    final nextDue = DateTime(2026, 10, 20, 8);
    final current = MemoryState.initial('w1').copyWith(
      stability: 20,
      difficulty: 5,
      lastReviewedAt: DateTime(2026, 9, 26, 8),
      nextReviewAt: nextDue,
    );
    final updated = evaluator.applyResult(
      current,
      result(
        direction: QuizDirection.koreanToJapanese,
        correct: true,
        responseMs: 1200,
        feeling: MemoryFeeling.remembered,
        at: DateTime(2026, 9, 26, 8, 2),
      ),
    );
    // 2026-09-27 FSRS는 예정보다 일찍 복습해도 회상 확률(R)이 높다는 사실을
    // 공식 안에서 그대로 반영하므로, stability를 강제로 얼리지 않고 매번
    // 새로 계산해도 값이 줄어들지는 않는다.
    expect(updated.stability, greaterThanOrEqualTo(current.stability));
    expect(updated.nextReviewAt, isNotNull);
    expect(updated.nextReviewAt!.isAfter(DateTime(2026, 9, 26, 8, 2)), isTrue);
  });

  test('stage stays within 0..7 and difficulty within 1..10 across many reviews', () {
    var high = MemoryState.initial('w1');
    for (var i = 0; i < 6; i++) {
      high = evaluator.applyResult(
        high,
        result(
          direction: QuizDirection.koreanToJapanese,
          correct: true,
          responseMs: 500,
          feeling: MemoryFeeling.instantRecall,
          at: DateTime(2026, 9, 26 + i, 8),
        ),
      );
      expect(high.stage, inInclusiveRange(0, 7));
      expect(high.difficulty, inInclusiveRange(1.0, 10.0));
      expect(high.stability, greaterThan(0));
    }

    var low = MemoryState.initial('w1');
    for (var i = 0; i < 6; i++) {
      low = evaluator.applyResult(
        low,
        result(
          direction: QuizDirection.koreanToJapanese,
          correct: false,
          responseMs: 500,
          feeling: MemoryFeeling.didNotKnow,
          at: DateTime(2026, 9, 26 + i, 8),
        ),
      );
      expect(low.stage, inInclusiveRange(0, 7));
      expect(low.difficulty, inInclusiveRange(1.0, 10.0));
    }
  });

  test('reaching stage 6 or above records longTermReachedAt only once', () {
    final firstAt = DateTime(2026, 9, 26, 8);
    // 2026-09-27 stability 40일은 stageForIntervalDays에서 항상 6번 버킷(30~59일)에
    // 들어가고, 짧은 경과시간에 정답을 한 번 더 맞혀도 성장폭이 작아 그 버킷을
    // 벗어나지 않으므로 안전하게 stage>=6 진입 시점을 재현할 수 있다.
    final almostLongTerm = MemoryState.initial('w1').copyWith(
      stability: 40,
      difficulty: 5,
    );
    final reachedLongTerm = evaluator.applyResult(
      almostLongTerm,
      result(
        direction: QuizDirection.koreanToJapanese,
        correct: true,
        responseMs: 1000,
        feeling: MemoryFeeling.remembered,
        at: firstAt,
      ),
    );
    expect(reachedLongTerm.stage, greaterThanOrEqualTo(6));
    expect(reachedLongTerm.longTermReachedAt, firstAt);

    final later = evaluator.applyResult(
      reachedLongTerm,
      result(
        direction: QuizDirection.koreanToJapanese,
        correct: true,
        responseMs: 900,
        feeling: MemoryFeeling.remembered,
        at: DateTime(2026, 10, 26),
      ),
    );
    expect(later.longTermReachedAt, firstAt);
  });
}
