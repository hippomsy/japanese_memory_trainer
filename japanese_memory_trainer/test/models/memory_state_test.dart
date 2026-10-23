import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/review_result.dart';

void main() {
  group('MemoryState', () {
    test('MemoryState clamps stage below zero to 0', () {
      final state = MemoryState.initial('w1').copyWith(stage: -3);
      expect(state.stage, 0);
    });

    test('MemoryState clamps stage above seven to 7', () {
      final state = MemoryState.initial('w1').copyWith(stage: 99);
      expect(state.stage, 7);
    });

    // 2026-09-27 FSRS 도입으로 stability/difficulty/lapses가 추가되어 직접
    // 생성자를 쓰는 이 테스트도 세 값을 함께 채우고 왕복 결과를 검증한다.
    test('MemoryState JSON round trip preserves counts, scores, longTermReachedAt and FSRS fields', () {
      final original = MemoryState(
        wordId: 'w1',
        stage: 6,
        correctCount: 8,
        wrongCount: 2,
        consecutiveCorrect: 3,
        lastReviewedAt: DateTime(2026, 9, 26, 8),
        nextReviewAt: DateTime(2026, 10, 26, 8),
        averageResponseMs: 2450,
        recognitionScore: 72,
        recallScore: 61,
        dangerScore: 18,
        longTermReachedAt: DateTime(2026, 9, 25, 9),
        stability: 32.5,
        difficulty: 6.4,
        lapses: 2,
      );

      final restored = MemoryState.fromJson(original.toJson());
      expect(restored.wordId, original.wordId);
      expect(restored.stage, original.stage);
      expect(restored.correctCount, original.correctCount);
      expect(restored.wrongCount, original.wrongCount);
      expect(restored.consecutiveCorrect, original.consecutiveCorrect);
      expect(restored.lastReviewedAt, original.lastReviewedAt);
      expect(restored.nextReviewAt, original.nextReviewAt);
      expect(restored.averageResponseMs, original.averageResponseMs);
      expect(restored.recognitionScore, original.recognitionScore);
      expect(restored.recallScore, original.recallScore);
      expect(restored.dangerScore, original.dangerScore);
      expect(restored.longTermReachedAt, original.longTermReachedAt);
      expect(restored.stability, original.stability);
      expect(restored.difficulty, original.difficulty);
      expect(restored.lapses, original.lapses);
    });
  });

  test('ReviewResult records direction, correctness, responseMs and feeling', () {
    final reviewedAt = DateTime(2026, 9, 26, 8, 30);
    final result = ReviewResult(
      wordId: 'w1',
      direction: QuizDirection.koreanToJapanese,
      isCorrect: true,
      responseMs: 3200,
      feeling: MemoryFeeling.remembered,
      reviewedAt: reviewedAt,
    );

    expect(result.wordId, 'w1');
    expect(result.direction, QuizDirection.koreanToJapanese);
    expect(result.isCorrect, isTrue);
    expect(result.responseMs, 3200);
    expect(result.feeling, MemoryFeeling.remembered);
    expect(result.reviewedAt, reviewedAt);
  });
}
