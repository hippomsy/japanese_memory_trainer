import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/services/review_scheduler.dart';

/// 2026-09-27 답변 결과를 FSRS 기억 모델(stability/difficulty)과 인지방향별
/// 점수, 위험도에 반영한다. 실제 정오답은 정답/오답 그 자체로, 체감 난이도는
/// FSRS 등급(Again/Hard/Good/Easy)으로 각각 반영해 두 정보를 모두 살린다.
class MemoryEvaluator {
  MemoryEvaluator({ReviewScheduler? scheduler})
      : _scheduler = scheduler ?? ReviewScheduler();

  final ReviewScheduler _scheduler;

  /// 2026-09-27 정답/오답, 회상 방향, 반응시간, 체감 난이도를 한 번에 평가해
  /// FSRS로 다음 복습 시점을 다시 계산한 새 상태를 만든다.
  MemoryState applyResult(MemoryState current, ReviewResult result) {
    final rating = _toFsrsRating(result);
    final isNewWord = current.stability <= 0;

    final elapsedDays = current.lastReviewedAt == null
        ? 0.0
        : result.reviewedAt
            .difference(current.lastReviewedAt!)
            .inMilliseconds /
            Duration.millisecondsPerDay;

    double newDifficulty;
    double newStability;

    if (isNewWord) {
      newDifficulty = _scheduler.initialDifficulty(rating);
      newStability = _scheduler.initialStability(rating);
    } else {
      final retrievability = _scheduler.retrievability(
        stabilityDays: current.stability,
        elapsedDays: elapsedDays,
      );
      newDifficulty = _scheduler.nextDifficulty(
        difficulty: current.difficulty,
        rating: rating,
      );
      newStability = rating == 1
          ? _scheduler.nextStabilityOnForget(
              difficulty: newDifficulty,
              stability: current.stability,
              retrievability: retrievability,
            )
          : _scheduler.nextStabilityOnRecall(
              difficulty: newDifficulty,
              stability: current.stability,
              retrievability: retrievability,
              rating: rating,
            );
    }

    final intervalDays = _scheduler.intervalDaysForStability(newStability);
    final nextReviewAt = _scheduler.nextReviewAt(
      stabilityDays: newStability,
      from: result.reviewedAt,
    );
    final newStage = _scheduler.stageForIntervalDays(intervalDays);

    var recognitionScore = current.recognitionScore;
    var recallScore = current.recallScore;
    var dangerScore = current.dangerScore;

    switch (result.direction) {
      case QuizDirection.koreanToJapanese:
        if (result.isCorrect) {
          recallScore += 10;
        } else {
          recallScore -= 8;
          dangerScore += 12;
        }
        break;
      case QuizDirection.sentenceBlank:
        if (result.isCorrect) {
          recallScore += 8;
        } else {
          recallScore -= 8;
          dangerScore += 10;
        }
        break;
      case QuizDirection.japaneseToKorean:
        if (result.isCorrect) {
          recognitionScore += 6;
        } else {
          recognitionScore -= 5;
          dangerScore += 8;
        }
        break;
      case QuizDirection.listening:
        if (result.isCorrect) {
          recognitionScore += 6;
        } else {
          recognitionScore -= 5;
          dangerScore += 8;
        }
        break;
    }

    final slowOrHard = result.responseMs >= 5000 ||
        result.feeling == MemoryFeeling.hardRecall ||
        result.feeling == MemoryFeeling.didNotKnow;
    if (result.isCorrect) {
      dangerScore += slowOrHard ? 5 : -3;
    }

    recognitionScore = recognitionScore.clamp(0, 100).toInt();
    recallScore = recallScore.clamp(0, 100).toInt();
    if (recognitionScore >= recallScore + 20) {
      dangerScore += 4;
    }
    dangerScore = dangerScore.clamp(0, 100).toInt();

    final previousReviews = current.correctCount + current.wrongCount;
    final averageResponseMs = previousReviews == 0
        ? result.responseMs.toDouble()
        : ((current.averageResponseMs * previousReviews) + result.responseMs) /
            (previousReviews + 1);

    final longTermReachedAt = current.longTermReachedAt ??
        (newStage >= 6 ? result.reviewedAt : null);

    return current.copyWith(
      stage: newStage,
      correctCount: current.correctCount + (result.isCorrect ? 1 : 0),
      wrongCount: current.wrongCount + (result.isCorrect ? 0 : 1),
      consecutiveCorrect:
          result.isCorrect ? current.consecutiveCorrect + 1 : 0,
      lastReviewedAt: result.reviewedAt,
      nextReviewAt: nextReviewAt,
      averageResponseMs: averageResponseMs,
      recognitionScore: recognitionScore,
      recallScore: recallScore,
      dangerScore: dangerScore,
      longTermReachedAt: longTermReachedAt,
      stability: newStability,
      difficulty: newDifficulty,
      lapses: current.lapses + (rating == 1 ? 1 : 0),
    );
  }

  /// 2026-09-27 정오답과 체감 난이도를 FSRS 등급(1=Again,2=Hard,3=Good,
  /// 4=Easy)으로 합친다. 오답이면 체감과 무관하게 무조건 Again으로 본다.
  int _toFsrsRating(ReviewResult result) {
    if (!result.isCorrect) return 1;
    switch (result.feeling) {
      case MemoryFeeling.didNotKnow:
        // 2026-09-27 객관식을 찍어서 맞힌 경우로 보고 보수적으로 Again 취급한다.
        return 1;
      case MemoryFeeling.hardRecall:
        return 2;
      case MemoryFeeling.remembered:
        return 3;
      case MemoryFeeling.instantRecall:
        return 4;
    }
  }
}
