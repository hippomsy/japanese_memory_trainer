import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/services/review_scheduler.dart';

// 2026-09-27 Stage 0~7 고정 간격 대신 FSRS 공식을 쓰므로, 이 테스트도
// nextReviewAt(stage: ...) 대신 stability 기반 API를 검증하도록 다시 작성했다.
// requestRetention 기본값 0.9에서는 "간격(일) == stability(일)"이 수학적으로
// 정확히 성립하므로(factor·decay가 그렇게 되도록 정의됨) 아래 기대값들은
// 근사치가 아니라 정확한 항등식에 기반한다.
void main() {
  final scheduler = ReviewScheduler();
  final from = DateTime(2026, 9, 26, 8, 0);

  test('interval in days equals stability in days at the default 90% retention target', () {
    for (final stability in [0.5, 1.0, 3.1262, 10.0, 40.0]) {
      expect(
        scheduler.intervalDaysForStability(stability),
        closeTo(stability, 0.0005),
      );
    }
  });

  test('initial stability by rating follows Again < Hard < Good < Easy', () {
    final again = scheduler.initialStability(1);
    final hard = scheduler.initialStability(2);
    final good = scheduler.initialStability(3);
    final easy = scheduler.initialStability(4);
    expect(again, lessThan(hard));
    expect(hard, lessThan(good));
    expect(good, lessThan(easy));
  });

  test('nextReviewAt adds the stability-derived interval to the given time', () {
    final stability = 3.1262;
    final expectedMillis = (stability * Duration.millisecondsPerDay).round();
    expect(
      scheduler.nextReviewAt(stabilityDays: stability, from: from),
      from.add(Duration(milliseconds: expectedMillis)),
    );
  });

  test('retrievability decreases as more days pass since the last review', () {
    final stability = 10.0;
    final soon = scheduler.retrievability(stabilityDays: stability, elapsedDays: 1);
    final later = scheduler.retrievability(stabilityDays: stability, elapsedDays: 20);
    expect(soon, greaterThan(later));
    expect(soon, lessThanOrEqualTo(1));
    expect(later, greaterThanOrEqualTo(0));
  });

  test('failing a review (Again) always yields a lower stability than a mid-range value', () {
    final forgotten = scheduler.nextStabilityOnForget(
      difficulty: 5,
      stability: 20,
      retrievability: 0.9,
    );
    expect(forgotten, lessThan(20));
  });

  test('recalling successfully never decreases stability', () {
    for (final rating in [2, 3, 4]) {
      final grown = scheduler.nextStabilityOnRecall(
        difficulty: 5,
        stability: 10,
        retrievability: 0.85,
        rating: rating,
      );
      expect(grown, greaterThanOrEqualTo(10));
    }
  });

  test('difficulty stays clamped between 1 and 10 across repeated Again ratings', () {
    var difficulty = scheduler.initialDifficulty(1);
    for (var i = 0; i < 20; i++) {
      difficulty = scheduler.nextDifficulty(difficulty: difficulty, rating: 1);
      expect(difficulty, inInclusiveRange(1.0, 10.0));
    }
  });

  test('stageForIntervalDays buckets match the previous fixed-schedule cutoffs', () {
    expect(scheduler.stageForIntervalDays(0.4), 1);
    expect(scheduler.stageForIntervalDays(1.5), 2);
    expect(scheduler.stageForIntervalDays(5), 3);
    expect(scheduler.stageForIntervalDays(10), 4);
    expect(scheduler.stageForIntervalDays(20), 5);
    expect(scheduler.stageForIntervalDays(45), 6);
    expect(scheduler.stageForIntervalDays(90), 7);
  });

  test('isDue returns true when no next review exists or review time passed', () {
    expect(scheduler.isDue(MemoryState.initial('w1'), from), isTrue);
    expect(
      scheduler.isDue(
        MemoryState.initial('w1').copyWith(nextReviewAt: from.subtract(const Duration(seconds: 1))),
        from,
      ),
      isTrue,
    );
    expect(
      scheduler.isDue(
        MemoryState.initial('w1').copyWith(nextReviewAt: from.add(const Duration(days: 1))),
        from,
      ),
      isFalse,
    );
  });
}
