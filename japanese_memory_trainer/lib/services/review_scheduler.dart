import 'dart:math' as math;

import 'package:kioku_japanese/models/memory_state.dart';

/// 2026-09-27 실제 배포판(마나나 일본어)과 동일하게 Stage 0~7 고정 간격 대신
/// FSRS(Free Spaced Repetition Scheduler) 알고리즘으로 다음 복습 시점을 계산한다.
/// 기본 가중치는 FSRS-4.5 공개 기본값(w0~w16, 단기망각 보정용 w17/w18은 이
/// 앱이 일 단위 스케줄링만 사용하므로 제외했다)을 그대로 사용한다.
class ReviewScheduler {
  ReviewScheduler({double requestRetention = 0.9})
      : requestRetention = requestRetention.clamp(0.7, 0.97).toDouble();

  /// 2026-09-27 사용자가 이 단어를 다시 봤을 때 기억해낼 확률로 잡을 목표치다.
  /// 값이 높을수록 복습 간격이 짧아지고, 낮을수록 간격이 길어진다.
  final double requestRetention;

  static const double _factor = 19 / 81;
  static const double _decay = -0.5;

  /// 2026-09-27 FSRS 기본 가중치(w0~w16). w0~w3은 최초 노출 시 등급별 초기
  /// stability, w4~w7은 난이도 공식, w8~w10은 정답 시 stability 증가,
  /// w11~w14는 오답(망각) 시 stability 재추정, w15~w16은 Hard/Easy 보정이다.
  static const List<double> _w = <double>[
    0.4072,
    1.1829,
    3.1262,
    15.4722,
    7.2102,
    0.5316,
    1.0651,
    0.0234,
    1.616,
    0.1544,
    1.0824,
    1.9813,
    0.0953,
    0.2975,
    2.2042,
    0.2407,
    2.9466,
  ];

  static const double _minIntervalDays = 10 / (24 * 60);
  static const double _maxIntervalDays = 3650;

  /// 2026-09-27 등급(1=Again,2=Hard,3=Good,4=Easy) 최초 노출 시 초기 stability다.
  double initialStability(int rating) {
    final index = (rating - 1).clamp(0, _w.length - 1).toInt();
    return _w[index];
  }

  /// 2026-09-27 등급 최초 노출 시 초기 difficulty다(1~10로 보정).
  double initialDifficulty(int rating) {
    final value = _w[4] - (rating - 3) * _w[5];
    return value.clamp(1.0, 10.0).toDouble();
  }

  /// 2026-09-27 이번 복습 등급을 반영해 난이도를 갱신하고, 평균 난이도(w4)
  /// 방향으로 살짝 되돌리는 평균회귀를 적용한다.
  double nextDifficulty({required double difficulty, required int rating}) {
    final baseline = difficulty <= 0 ? _w[4] : difficulty;
    final reduced = baseline - _w[6] * (rating - 3);
    final reverted = _w[7] * _w[4] + (1 - _w[7]) * reduced;
    return reverted.clamp(1.0, 10.0).toDouble();
  }

  /// 2026-09-27 경과일과 현재 stability로부터 "지금 이 단어를 기억해낼 확률"을
  /// 추정한다(망각 곡선).
  double retrievability({required double stabilityDays, required double elapsedDays}) {
    if (stabilityDays <= 0) return 0;
    final t = elapsedDays < 0 ? 0.0 : elapsedDays;
    return math.pow(1 + _factor * t / stabilityDays, _decay).toDouble();
  }

  /// 2026-09-27 정답(등급 2~4)일 때 새로운 stability를 계산한다. 난이도가
  /// 낮을수록, 망각 직전(회상 확률이 낮았을수록) 더 크게 늘어난다.
  double nextStabilityOnRecall({
    required double difficulty,
    required double stability,
    required double retrievability,
    required int rating,
  }) {
    final safeStability = stability <= 0 ? 0.01 : stability;
    final hardPenalty = rating == 2 ? _w[15] : 1.0;
    final easyBonus = rating == 4 ? _w[16] : 1.0;
    final growth = math.exp(_w[8]) *
        (11 - difficulty) *
        math.pow(safeStability, -_w[9]) *
        (math.exp((1 - retrievability) * _w[10]) - 1) *
        hardPenalty *
        easyBonus;
    return safeStability * (1 + growth);
  }

  /// 2026-09-27 오답(등급 1, Again)일 때 stability를 다시 추정한다. 기존
  /// stability와 난이도를 반영하되 값 자체는 크게 줄어든다(망각 반영).
  double nextStabilityOnForget({
    required double difficulty,
    required double stability,
    required double retrievability,
  }) {
    final safeStability = stability <= 0 ? 0.01 : stability;
    final safeDifficulty = difficulty <= 0 ? _w[4] : difficulty;
    return _w[11] *
        math.pow(safeDifficulty, -_w[12]) *
        (math.pow(safeStability + 1, _w[13]) - 1) *
        math.exp((1 - retrievability) * _w[14]);
  }

  /// 2026-09-27 목표 회상 확률(requestRetention)을 만족하는 다음 복습까지의
  /// 간격(일)을 stability로부터 역산한다.
  double intervalDaysForStability(double stabilityDays) {
    if (stabilityDays <= 0) return 0;
    final target = math.pow(requestRetention, 1 / _decay).toDouble();
    final days = (stabilityDays / _factor) * (target - 1);
    return days.clamp(_minIntervalDays, _maxIntervalDays).toDouble();
  }

  /// 2026-09-27 stability로 계산한 간격을 기준 시각에 더해 다음 복습 시각을
  /// 만든다. 간격이 하루 미만이면 분 단위까지 반영한다.
  DateTime nextReviewAt({required double stabilityDays, required DateTime from}) {
    final days = intervalDaysForStability(stabilityDays);
    final millis = (days * Duration.millisecondsPerDay).round();
    return from.add(Duration(milliseconds: millis));
  }

  /// 2026-09-27 다음 복습일이 없거나 현재 시각 이전이면 복습 대상으로 본다.
  bool isDue(MemoryState state, DateTime now) {
    final next = state.nextReviewAt;
    return next == null || !next.isAfter(now);
  }

  /// 2026-09-27 통계/UI 화면이 계속 stage(0~7)로 "장기기억 정착 여부"를 판단할
  /// 수 있도록, 계산된 복습 간격(일)을 예전 Stage 0~7 구간과 같은 경계값으로
  /// 나눈 버킷 번호로 변환한다. 실제 스케줄링에는 stability를 직접 쓰고,
  /// 이 값은 화면 표시/통계 전용이다.
  int stageForIntervalDays(double intervalDays) {
    if (intervalDays < 1) return 1;
    if (intervalDays < 3) return 2;
    if (intervalDays < 7) return 3;
    if (intervalDays < 14) return 4;
    if (intervalDays < 30) return 5;
    if (intervalDays < 60) return 6;
    return 7;
  }
}
