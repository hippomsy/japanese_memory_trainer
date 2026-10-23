/// 2026-09-27 단어 하나의 장기기억 상태를 저장한다. FSRS 복습 엔진이 쓰는
/// stability(기억 안정도, 일 단위)와 difficulty(난이도, 1~10)를 추가로 들고 있고,
/// stage/recognitionScore/recallScore/dangerScore는 기존 화면(통계, 위험 단어,
/// 주간 보스전)이 그대로 읽을 수 있도록 stability로부터 파생된 값을 계속 담는다.
class MemoryState {
  const MemoryState({
    required this.wordId,
    required this.stage,
    required this.correctCount,
    required this.wrongCount,
    required this.consecutiveCorrect,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.averageResponseMs,
    required this.recognitionScore,
    required this.recallScore,
    required this.dangerScore,
    required this.longTermReachedAt,
    required this.stability,
    required this.difficulty,
    required this.lapses,
  });

  final String wordId;
  final int stage;
  final int correctCount;
  final int wrongCount;
  final int consecutiveCorrect;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final double averageResponseMs;
  final int recognitionScore;
  final int recallScore;
  final int dangerScore;
  final DateTime? longTermReachedAt;

  /// 2026-09-27 FSRS가 추정한 현재 기억 안정도(일 단위). 0이면 아직 한 번도
  /// 복습하지 않은 단어라는 뜻이다.
  final double stability;

  /// 2026-09-27 FSRS가 추정한 이 단어의 체감 난이도(1~10). 0이면 미설정 상태다.
  final double difficulty;

  /// 2026-09-27 정답을 못 맞혀 FSRS가 "망각(Again)"으로 처리한 누적 횟수다.
  final int lapses;

  /// 2026-09-27 새 단어의 초기 기억 상태를 만든다.
  factory MemoryState.initial(String wordId) {
    return MemoryState(
      wordId: wordId,
      stage: 0,
      correctCount: 0,
      wrongCount: 0,
      consecutiveCorrect: 0,
      lastReviewedAt: null,
      nextReviewAt: null,
      averageResponseMs: 0,
      recognitionScore: 0,
      recallScore: 0,
      dangerScore: 0,
      longTermReachedAt: null,
      stability: 0,
      difficulty: 0,
      lapses: 0,
    );
  }

  /// 2026-09-27 stage와 점수 범위를 안전하게 보정하며 새 상태를 만든다.
  MemoryState copyWith({
    String? wordId,
    int? stage,
    int? correctCount,
    int? wrongCount,
    int? consecutiveCorrect,
    DateTime? lastReviewedAt,
    bool clearLastReviewedAt = false,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    double? averageResponseMs,
    int? recognitionScore,
    int? recallScore,
    int? dangerScore,
    DateTime? longTermReachedAt,
    bool clearLongTermReachedAt = false,
    double? stability,
    double? difficulty,
    int? lapses,
  }) {
    return MemoryState(
      wordId: wordId ?? this.wordId,
      stage: _clampStage(stage ?? this.stage),
      correctCount: _nonNegative(correctCount ?? this.correctCount),
      wrongCount: _nonNegative(wrongCount ?? this.wrongCount),
      consecutiveCorrect:
          _nonNegative(consecutiveCorrect ?? this.consecutiveCorrect),
      lastReviewedAt:
          clearLastReviewedAt ? null : lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: clearNextReviewAt ? null : nextReviewAt ?? this.nextReviewAt,
      averageResponseMs:
          (averageResponseMs ?? this.averageResponseMs)
              .clamp(0, double.infinity)
              .toDouble(),
      recognitionScore: _clampScore(recognitionScore ?? this.recognitionScore),
      recallScore: _clampScore(recallScore ?? this.recallScore),
      dangerScore: _clampScore(dangerScore ?? this.dangerScore),
      longTermReachedAt: clearLongTermReachedAt
          ? null
          : longTermReachedAt ?? this.longTermReachedAt,
      stability: (stability ?? this.stability).clamp(0, double.infinity).toDouble(),
      difficulty: (difficulty ?? this.difficulty).clamp(0, 10).toDouble(),
      lapses: _nonNegative(lapses ?? this.lapses),
    );
  }

  /// 2026-09-27 로컬 저장용 JSON으로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'wordId': wordId,
      'stage': stage,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'consecutiveCorrect': consecutiveCorrect,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'averageResponseMs': averageResponseMs,
      'recognitionScore': recognitionScore,
      'recallScore': recallScore,
      'dangerScore': dangerScore,
      'longTermReachedAt': longTermReachedAt?.toIso8601String(),
      'stability': stability,
      'difficulty': difficulty,
      'lapses': lapses,
    };
  }

  /// 2026-09-27 손상된 숫자/날짜가 있어도 가능한 값은 안전하게 복원한다.
  /// 구버전(FSRS 도입 이전)에 저장된 데이터는 stability/difficulty/lapses가
  /// 없으므로 0으로 복원되고, 다음 복습에서 최초 학습처럼 새로 추정된다.
  factory MemoryState.fromJson(Map<String, dynamic> json) {
    return MemoryState(
      wordId: json['wordId']?.toString() ?? '',
      stage: _clampStage(_toInt(json['stage'])),
      correctCount: _nonNegative(_toInt(json['correctCount'])),
      wrongCount: _nonNegative(_toInt(json['wrongCount'])),
      consecutiveCorrect: _nonNegative(_toInt(json['consecutiveCorrect'])),
      lastReviewedAt: _tryDate(json['lastReviewedAt']),
      nextReviewAt: _tryDate(json['nextReviewAt']),
      averageResponseMs: _toDouble(json['averageResponseMs'])
          .clamp(0, double.infinity)
          .toDouble(),
      recognitionScore: _clampScore(_toInt(json['recognitionScore'])),
      recallScore: _clampScore(_toInt(json['recallScore'])),
      dangerScore: _clampScore(_toInt(json['dangerScore'])),
      longTermReachedAt: _tryDate(json['longTermReachedAt']),
      stability: _toDouble(json['stability']).clamp(0, double.infinity).toDouble(),
      difficulty: _toDouble(json['difficulty']).clamp(0, 10).toDouble(),
      lapses: _nonNegative(_toInt(json['lapses'])),
    );
  }

  static int _clampStage(int value) => value.clamp(0, 7).toInt();
  static int _clampScore(int value) => value.clamp(0, 100).toInt();
  static int _nonNegative(int value) => value < 0 ? 0 : value;

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _tryDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
